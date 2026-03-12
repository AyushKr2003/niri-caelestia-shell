#include "sysmonitor.hpp"

#include <QFile>
#include <QDir>
#include <QTextStream>
#include <QProcess>
#include <QDateTime>
#include <QDebug>
#include <QRegularExpression>
#include <sys/sysinfo.h>
#include <unistd.h>
#include <sys/vfs.h>
#include <QStorageInfo>

namespace caelestia {

SysMonitor::SysMonitor(QObject* parent) : QObject(parent) {
    m_clockTicks = sysconf(_SC_CLK_TCK);
    
    // Initialize default structures so QML doesn't crash on undefined properties
    m_gpu["type"] = "NONE";
    m_gpu["name"] = "";
    m_gpu["utilization"] = 0.0;
    m_gpu["temperature"] = 0.0;
    
    m_cpu["temperature"] = 0.0;
    m_cpu["model"] = "";
    m_cpu["frequency"] = 0.0;
    
    connect(&m_timer, &QTimer::timeout, this, &SysMonitor::updateAll);
    m_timer.setInterval(m_updateInterval);
    updateSystemOnce(); // Static info
    updateCpu(); // Initial CPU info
    updateGpuOnce(); // Static GPU info
}

SysMonitor::~SysMonitor() {}

QVariantMap SysMonitor::memory() const { return m_memory; }
QVariantMap SysMonitor::cpu() const { return m_cpu; }
QVariantList SysMonitor::network() const { return m_network; }
QVariantList SysMonitor::disk() const { return m_disk; }
QVariantList SysMonitor::processes() const { return m_processes; }
QVariantMap SysMonitor::system() const { return m_system; }
QVariantList SysMonitor::diskmounts() const { return m_diskmounts; }
QVariantMap SysMonitor::gpu() const { return m_gpu; }

int SysMonitor::updateInterval() const { return m_updateInterval; }
void SysMonitor::setUpdateInterval(int interval) {
    if (m_updateInterval != interval) {
        m_updateInterval = interval;
        m_timer.setInterval(m_updateInterval);
        emit updateIntervalChanged();
    }
}

int SysMonitor::maxProcesses() const { return m_maxProcesses; }
void SysMonitor::setMaxProcesses(int max) {
    if (m_maxProcesses != max) {
        m_maxProcesses = max;
        emit maxProcessesChanged();
    }
}

QString SysMonitor::sortBy() const { return m_sortBy; }
void SysMonitor::setSortBy(const QString& sort) {
    if (m_sortBy != sort) {
        m_sortBy = sort;
        emit sortByChanged();
    }
}

void SysMonitor::start() {
    if (!m_timer.isActive()) {
        updateAll();
        m_timer.start();
    }
}

void SysMonitor::stop() {
    m_timer.stop();
}

void SysMonitor::updateAll() {
    updateMemory();
    updateCpu();
    updateNetwork();
    updateDisk();
    updateProcesses();
    updateDiskmounts();
    updateGpu();
}

void SysMonitor::updateMemory() {
    QFile file("/proc/meminfo");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QByteArray content = file.readAll();
    QTextStream in(&content);
    qint64 memTotal = 0, memFree = 0, memAvailable = 0;
    qint64 buffers = 0, cached = 0, shared = 0;
    qint64 swapTotal = 0, swapFree = 0;

    QRegularExpression spaceRe("\\s+");

    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty()) continue;
        
        QStringList parts = line.split(spaceRe, Qt::SkipEmptyParts);
        if (parts.size() < 2) continue;
        
        qint64 val = parts[1].toLongLong();
        if (parts[0] == "MemTotal:") memTotal = val;
        else if (parts[0] == "MemFree:") memFree = val;
        else if (parts[0] == "MemAvailable:") memAvailable = val;
        else if (parts[0] == "Buffers:") buffers = val;
        else if (parts[0] == "Cached:") cached = val;
        else if (parts[0] == "Shmem:") shared = val;
        else if (parts[0] == "SwapTotal:") swapTotal = val;
        else if (parts[0] == "SwapFree:") swapFree = val;
    }
    
    m_memTotalKB = memTotal > 0 ? memTotal : 1;

    QVariantMap newMem;
    newMem.insert("total", memTotal);
    newMem.insert("free", memFree);
    newMem.insert("available", memAvailable);
    newMem.insert("buffers", buffers);
    newMem.insert("cached", cached);
    newMem.insert("shared", shared);
    newMem.insert("swaptotal", swapTotal);
    newMem.insert("swapfree", swapFree);

    if (m_memory != newMem) {
        m_memory = newMem;
        emit memoryChanged();
    }
}

void SysMonitor::updateCpu() {
    // 1. Parse /proc/stat for usage and core count
    QFile file("/proc/stat");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QByteArray content = file.readAll();
    file.close();
    QTextStream in(&content);
    QVariantList total;
    QVariantList cores;
    int count = 0;

    QRegularExpression spaceRe("\\s+");
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty()) continue;
        
        if (line.startsWith("cpu ")) {
            QStringList parts = line.split(spaceRe, Qt::SkipEmptyParts);
            for (int i = 1; i < parts.size(); ++i) total.append(parts[i].toLongLong());
        } else if (line.startsWith("cpu")) {
            QStringList parts = line.split(spaceRe, Qt::SkipEmptyParts);
            QVariantList coreProps;
            for (int i = 1; i < parts.size(); ++i) coreProps.append(parts[i].toLongLong());
            cores.append(QVariant(coreProps));
            count++;
        }
    }

    QVariantMap newCpu = m_cpu;
    newCpu.insert("total", total);
    newCpu.insert("cores", cores);
    newCpu.insert("count", count);

    // 2. Parse /proc/cpuinfo for model and frequency (if missing)
    if (newCpu.value("model").toString().isEmpty()) {
        QProcess grep;
        grep.start("sh", QStringList() << "-c" << "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2");
        grep.waitForFinished(500);
        QString model = QString::fromUtf8(grep.readAllStandardOutput()).trimmed();
        if (!model.isEmpty()) {
            newCpu.insert("model", model);
        } else {
            // ARM fallback
            QProcess arm;
            arm.start("sh", QStringList() << "-c" << "grep -m1 'Hardware' /proc/cpuinfo | cut -d: -f2");
            arm.waitForFinished(500);
            model = QString::fromUtf8(arm.readAllStandardOutput()).trimmed();
            if (!model.isEmpty()) newCpu.insert("model", model);
        }
    }

    // 3. Frequency
    QFile clk("/proc/cpuinfo");
    if (clk.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream c(&clk);
        while (!c.atEnd()) {
            QString l = c.readLine();
            if (l.contains("cpu MHz", Qt::CaseInsensitive)) {
                newCpu.insert("frequency", l.section(':', 1).trimmed().toDouble());
                break;
            }
        }
    }
    
    // 4. Temperature
    bool tempFound = false;
    QDir hwmonDir("/sys/class/hwmon");
    for (const QString& hwmonD : hwmonDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        QFile nameF(hwmonDir.absoluteFilePath(hwmonD) + "/name");
        if (nameF.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString hwName = QString::fromUtf8(nameF.readAll().trimmed());
            if (hwName == "coretemp" || hwName == "k10temp" || hwName == "zenpower") {
                QDir hwD(hwmonDir.absoluteFilePath(hwmonD));
                QStringList inputs = hwD.entryList(QStringList() << "temp*_input", QDir::Files);
                if (!inputs.isEmpty()) {
                    QFile tempInput(hwD.absoluteFilePath(inputs.first()));
                    if (tempInput.open(QIODevice::ReadOnly | QIODevice::Text)) {
                        newCpu.insert("temperature", tempInput.readAll().trimmed().toDouble() / 1000.0);
                        tempFound = true;
                        break;
                    }
                }
            }
        }
    }
    
    if (!tempFound) {
        QFile tmp("/sys/class/thermal/thermal_zone0/temp");
        if (tmp.open(QIODevice::ReadOnly | QIODevice::Text)) {
            newCpu.insert("temperature", tmp.readAll().trimmed().toDouble() / 1000.0);
        } else if (!newCpu.contains("temperature")) {
            newCpu.insert("temperature", 0.0);
        }
    }

    if (m_cpu != newCpu) {
        m_cpu = newCpu;
        emit cpuChanged();
    }
}




void SysMonitor::updateNetwork() {
    QFile file("/proc/net/dev");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QTextStream in(&file);
    in.readLine(); // skip header
    in.readLine();

    QVariantList newNet;
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (!line.contains("eth") && !line.contains("en") && !line.contains("wl")) continue;
        QStringList parts = line.split(" ", Qt::SkipEmptyParts);
        if (parts.size() < 10) continue;
        QVariantMap iface;
        iface["name"] = parts[0].replace(":", "");
        iface["rx"] = parts[1].toLongLong();
        iface["tx"] = parts[9].toLongLong();
        newNet.append(iface);
    }

    m_network = newNet;
    emit networkChanged();
}

void SysMonitor::updateDisk() {
    QFile file("/proc/diskstats");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QTextStream in(&file);
    QVariantList newDisk;
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        QStringList parts = line.split(" ", Qt::SkipEmptyParts);
        if (parts.size() < 14) continue;
        QString name = parts[2];
        if (!name.startsWith("sd") && !name.startsWith("nvme") && !name.startsWith("vd")) continue;
        // Skip partitions (crude checking: if name ends in digit for sd or p\d+ for nvme)
        if (name.startsWith("sd") && name.at(name.length()-1).isDigit()) continue;
        if (name.startsWith("nvme") && name.contains("p")) continue;

        QVariantMap d;
        d["name"] = name;
        d["read"] = parts[5].toLongLong(); // sectors read
        d["write"] = parts[9].toLongLong(); // sectors written
        newDisk.append(d);
    }
    
    m_disk = newDisk;
    emit diskChanged();
}

void SysMonitor::updateSystem() {
    QFile file("/proc/loadavg");
    if (file.open(QIODevice::ReadOnly)) m_system["loadavg"] = QString::fromUtf8(file.readAll().trimmed().split(' ').mid(0,3).join(' '));
    file.close();

    struct sysinfo si;
    if (sysinfo(&si) == 0) {
        m_sysUptime = si.uptime;
        m_system["processes"] = si.procs;
    }
}

void SysMonitor::updateSystemOnce() {
    updateSystem(); // Grab first uptime
    
    // Set static system values
    QFile rel("/etc/os-release");
    if (rel.open(QIODevice::ReadOnly)) {
        QTextStream in(&rel);
        while(!in.atEnd()) {
            QString line = in.readLine();
            if (line.startsWith("PRETTY_NAME=")) {
                m_system["distro"] = line.section("=", 1).replace("\"", "");
                break;
            }
        }
    }
    
    QProcess uname;
    uname.start("uname", QStringList() << "-r" << "-m");
    uname.waitForFinished();
    QStringList outs = QString::fromUtf8(uname.readAllStandardOutput()).trimmed().split(" ", Qt::SkipEmptyParts);
    if(outs.size()>=2) {
        m_system["kernel"] = outs[0];
        m_system["arch"] = outs[1];
    }
    
    char hostname[256];
    if (gethostname(hostname, sizeof(hostname)) == 0) m_system["hostname"] = QString::fromUtf8(hostname);
    
    QFile dm("/sys/class/dmi/id/board_vendor");
    if (dm.open(QIODevice::ReadOnly)) m_system["motherboard"] = QString::fromUtf8(dm.readAll().trimmed());
    
    emit systemChanged();
}

void SysMonitor::updateProcesses() {
    updateSystem(); // Needed for uptime calculation
    
    QDir procDir("/proc");
    QStringList pidDirs = procDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    
    QHash<int, ProcessInfo> newProcesses;
    QVariantList parsedProcs;

    for (const QString& pidStr : pidDirs) {
        bool ok;
        int pid = pidStr.toInt(&ok);
        if (!ok) continue;

        QFile statFile(QString("/proc/%1/stat").arg(pid));
        if (!statFile.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
        
        QString statContent = statFile.readAll();
        // Comm name is enclosed in parenthesis
        int leftParen = statContent.indexOf("(");
        int rightParen = statContent.lastIndexOf(")");
        if(leftParen == -1 || rightParen == -1) continue;

        QString comm = statContent.mid(leftParen + 1, rightParen - leftParen - 1);
        QString afterCommm = statContent.mid(rightParen + 2);
        QStringList parts = afterCommm.split(" ", Qt::SkipEmptyParts);
        
        if (parts.size() < 22) continue; // safety
        
        int ppid = parts[1].toInt();
        qint64 utime = parts[11].toLongLong();
        qint64 stime = parts[12].toLongLong();
        qint64 starttime = parts[19].toLongLong();
        qint64 rss = parts[21].toLongLong(); // blocks 

        // Rss is allocated in pages, multiply by page size
        qint64 memoryKbs = (rss * sysconf(_SC_PAGESIZE)) / 1024;
        
        ProcessInfo pi;
        pi.pid = pid;
        pi.ppid = ppid;
        pi.memoryKB = memoryKbs;
        pi.memoryPercent = (double)pi.memoryKB / (double)m_memTotalKB * 100.0;
        pi.command = comm;
        pi.utime = utime;
        pi.stime = stime;

        // CPU calculation
        pi.cpu = 0.0;
        if (m_lastProcesses.contains(pid)) {
             ProcessInfo lastPi = m_lastProcesses[pid];
             qint64 total_time = (pi.utime + pi.stime) - (lastPi.utime + lastPi.stime);
             double seconds = ((double)m_updateInterval / 1000.0); // Exact elapsed interval roughly
             if (seconds > 0) {
                 pi.cpu = 100.0 * ((double)total_time / (double)m_clockTicks) / seconds;
             }
        }
        
        // Command line arguments for full detail caching
        QFile cmdFile(QString("/proc/%1/cmdline").arg(pid));
        if (cmdFile.open(QIODevice::ReadOnly)) {
            QByteArray cmdData = cmdFile.readAll();
            cmdData.replace('\0', ' ');
            pi.fullCommand = QString::fromUtf8(cmdData.trimmed());
        }
        if (pi.fullCommand.isEmpty()) pi.fullCommand = pi.command;

        newProcesses[pid] = pi;
    }
    
    m_lastProcesses = newProcesses;

    // Sort to QVariantList depending on m_sortBy
    QList<ProcessInfo> list = newProcesses.values();
    std::sort(list.begin(), list.end(), [&](const ProcessInfo& a, const ProcessInfo& b) {
        if (m_sortBy == "cpu") return a.cpu > b.cpu;
        if (m_sortBy == "memory") return a.memoryPercent > b.memoryPercent;
        if (m_sortBy == "pid") return a.pid > b.pid;
        return a.command < b.command; // default name a-z
    });
    
    int limit = qMin(m_maxProcesses, list.size());
    for(int i = 0; i < limit; i++) {
        QVariantMap p;
        p["pid"] = list[i].pid;
        p["ppid"] = list[i].ppid;
        p["cpu"] = list[i].cpu;
        p["memoryPercent"] = list[i].memoryPercent;
        p["memoryKB"] = list[i].memoryKB;
        p["command"] = list[i].command;
        p["fullCommand"] = list[i].fullCommand;
        
        QString displayName = list[i].command;
        if (displayName.length() > 15) displayName = displayName.left(15) + "...";
        p["displayName"] = displayName;
        
        parsedProcs.append(p);
    }

    if (m_processes != parsedProcs) {
        m_processes = parsedProcs;
        emit processesChanged();
    }
}

void SysMonitor::updateDiskmounts() {
    QVariantList newMounts;
    for (const QStorageInfo &storage : QStorageInfo::mountedVolumes()) {
        if (storage.isValid() && storage.isReady()) {
            if (!storage.isReadOnly()) {
                QString fsType = QString::fromUtf8(storage.fileSystemType());
                if (fsType == "tmpfs" || fsType == "devtmpfs") continue;
                
                QVariantMap m;
                m["device"] = QString::fromUtf8(storage.device());
                m["mount"] = storage.rootPath();
                m["fstype"] = fsType;
                
                qint64 size = storage.bytesTotal();
                qint64 avail = storage.bytesAvailable();
                qint64 used = size - avail;
                
                m["size"] = size / (1024 * 1024 * 1024); // GB roughly
                m["used"] = used / (1024 * 1024 * 1024);
                m["avail"] = avail / (1024 * 1024 * 1024);
                m["percent"] = size > 0 ? (used * 100) / size : 0;
                
                newMounts.append(m);
            }
        }
    }
    
    if (m_diskmounts != newMounts) {
        m_diskmounts = newMounts;
        emit diskmountsChanged();
    }
}

void SysMonitor::updateGpuOnce() {
    QString gType = "NONE";
    QString gName = "";

    // 1. Check NVIDIA via nvidia-smi
    QProcess nvidiaSmi;
    nvidiaSmi.start("nvidia-smi", QStringList() << "--query-gpu=name" << "--format=csv,noheader");
    nvidiaSmi.waitForFinished(1000);
    if (nvidiaSmi.exitStatus() == QProcess::NormalExit && nvidiaSmi.exitCode() == 0) {
        QString out = QString::fromUtf8(nvidiaSmi.readAllStandardOutput()).trimmed();
        qDebug() << "[SysMonitor] GPU detection nvidia-smi output:" << out;
        if (!out.isEmpty()) {
            gType = "NVIDIA";
            gName = out;
            // Clean up name
            gName = gName.replace(QRegularExpression("(?i)NVIDIA GeForce |NVIDIA |Graphics"), "").trimmed();
        }
    } else {
        qDebug() << "[SysMonitor] GPU detection nvidia-smi failed or not found";
    }

    // 2. Fallback to lspci and /sys/class/drm generic polling
    if (gType == "NONE") {
        QFile drmFile;
        QDir drmDir("/sys/class/drm");
        for (const QString& d : drmDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            if (d.startsWith("card") && !d.contains("-")) {
                if (QFile::exists(drmDir.absoluteFilePath(d) + "/device/gpu_busy_percent")) {
                    gType = "GENERIC";
                    break;
                }
            }
        }

        QProcess lspci;
        lspci.start("sh", QStringList() << "-c" << "lspci 2>/dev/null | grep -i 'vga\\|3d\\|display' | head -1");
        lspci.waitForFinished(1000);
        QString lspciOut = QString::fromUtf8(lspci.readAllStandardOutput()).trimmed();
        
        QRegularExpression bracketRe("\\[([^\\]]+)\\]");
        QRegularExpressionMatch match = bracketRe.match(lspciOut);
        if (match.hasMatch()) {
            gName = match.captured(1);
        } else if (lspciOut.contains(": ")) {
            gName = lspciOut.split(": ").last().trimmed();
        }
        
        if (!gName.isEmpty()) {
            gName = gName.replace(QRegularExpression("(?i)AMD Radeon |AMD |Intel |\\(R\\)|\\(TM\\)|Graphics|Corporation"), "").replace("  ", " ").trimmed();
        }
    }

    qDebug() << "[SysMonitor] updateGpuOnce result -" << "Type:" << gType << "Name:" << gName;

    m_gpu["type"] = gType;
    m_gpu["name"] = gName;
    m_gpu["utilization"] = 0.0;
    m_gpu["temperature"] = 0.0;
    emit gpuChanged();
}

void SysMonitor::updateGpu() {
    QString gType = m_gpu["type"].toString();
    if (gType == "NONE") return;

    QVariantMap newGpu = m_gpu;

    if (gType == "NVIDIA") {
        QProcess nvidiaSmi;
        nvidiaSmi.start("nvidia-smi", QStringList() << "--query-gpu=utilization.gpu,temperature.gpu" << "--format=csv,noheader,nounits");
        nvidiaSmi.waitForFinished(500);
        if (nvidiaSmi.exitStatus() == QProcess::NormalExit && nvidiaSmi.exitCode() == 0) {
            QString out = QString::fromUtf8(nvidiaSmi.readAllStandardOutput()).trimmed();
            QStringList parts = out.split(",");
            if (parts.size() == 2) {
                newGpu["utilization"] = parts[0].trimmed().toDouble() / 100.0;
                newGpu["temperature"] = parts[1].trimmed().toDouble();
            }
        }
    } else if (gType == "GENERIC") {
        // Read usage
        QDir drmDir("/sys/class/drm");
        double usageTotal = 0.0;
        int count = 0;
        QString cPath;
        
        for (const QString& d : drmDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            if (d.startsWith("card") && !d.contains("-")) {
                QFile useF(drmDir.absoluteFilePath(d) + "/device/gpu_busy_percent");
                if (useF.open(QIODevice::ReadOnly | QIODevice::Text)) {
                    usageTotal += useF.readAll().trimmed().toDouble() / 100.0;
                    count++;
                    cPath = drmDir.absoluteFilePath(d);
                }
            }
        }
        
        if (count > 0) newGpu["utilization"] = usageTotal / count;
        
        // Read temp via hwmon bounds inside device node
        if (!cPath.isEmpty()) {
            QDir dHw(cPath + "/device/hwmon");
            QStringList hwmons = dHw.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
            if (!hwmons.isEmpty()) {
                QDir hwM(dHw.absoluteFilePath(hwmons.first()));
                // Try temp1_input
                QFile tF(hwM.absoluteFilePath("temp1_input"));
                if (tF.open(QIODevice::ReadOnly | QIODevice::Text)) {
                    newGpu["temperature"] = tF.readAll().trimmed().toDouble() / 1000.0;
                }
            }
        }
    }

    qDebug() << "[SysMonitor] updateGpu result -" << "Utilization:" << newGpu["utilization"] << "Temp:" << newGpu["temperature"];

    if (m_gpu != newGpu) {
        m_gpu = newGpu;
        emit gpuChanged();
    }
}

} // namespace caelestia
