#pragma once

#include <qabstractitemmodel.h>
#include <qdir.h>
#include <qfilesystemwatcher.h>
#include <qfuture.h>
#include <qimagereader.h>
#include <qmimedatabase.h>
#include <qobject.h>
#include <qqmlintegration.h>

namespace caelestia {

class FileSystemEntry : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("FileSystemEntry instances can only be retrieved from a FileSystemModel")

    Q_PROPERTY(QString path READ path CONSTANT)
    Q_PROPERTY(QString relativePath READ relativePath CONSTANT)
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString parentDir READ parentDir CONSTANT)
    Q_PROPERTY(QString suffix READ suffix CONSTANT)
    Q_PROPERTY(qint64 size READ size CONSTANT)
    Q_PROPERTY(bool isDir READ isDir CONSTANT)
    Q_PROPERTY(bool isImage READ isImage CONSTANT)
    Q_PROPERTY(QString mimeType READ mimeType CONSTANT)

public:
    explicit FileSystemEntry(const QString& path, const QString& relativePath, QObject* parent = nullptr)
        : QObject(parent)
        , m_fileInfo(QFileInfo(path))
        , m_path(path)
        , m_relativePath(relativePath)
        , m_isImageInitialised(false)
        , m_mimeTypeInitialised(false) {}

    [[nodiscard]] QString path() const { return m_path; };
    [[nodiscard]] QString relativePath() const { return m_relativePath; };

    [[nodiscard]] QString name() const { return m_fileInfo.fileName(); };
    [[nodiscard]] QString parentDir() const { return m_fileInfo.absolutePath(); };
    [[nodiscard]] QString suffix() const { return m_fileInfo.completeSuffix(); };
    [[nodiscard]] qint64 size() const { return m_fileInfo.size(); };
    [[nodiscard]] bool isDir() const { return m_fileInfo.isDir(); };

    [[nodiscard]] bool isImage() {
        if (!m_isImageInitialised) {
            QImageReader reader(m_path);
            m_isImage = reader.canRead();
            m_isImageInitialised = true;
        }
        return m_isImage;
    }

    [[nodiscard]] QString mimeType() {
        if (!m_mimeTypeInitialised) {
            const QMimeDatabase db;
            m_mimeType = db.mimeTypeForFile(m_path).name();
            m_mimeTypeInitialised = true;
        }
        return m_mimeType;
    }

private:
    const QFileInfo m_fileInfo;

    const QString m_path;
    const QString m_relativePath;

    bool m_isImage;
    bool m_isImageInitialised;

    QString m_mimeType;
    bool m_mimeTypeInitialised;
};

class FileSystemModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(bool recursive READ recursive WRITE setRecursive NOTIFY recursiveChanged)
    Q_PROPERTY(bool watchChanges READ watchChanges WRITE setWatchChanges NOTIFY watchChangesChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(Filter filter READ filter WRITE setFilter NOTIFY filterChanged)

    Q_PROPERTY(QList<FileSystemEntry*> entries READ entries NOTIFY entriesChanged)

public:
    enum Filter {
        NoFilter,
        Images,
        Files,
        Dirs
    };
    Q_ENUM(Filter)

    explicit FileSystemModel(QObject* parent = nullptr)
        : QAbstractListModel(parent)
        , m_recursive(false)
        , m_watchChanges(true)
        , m_showHidden(false)
        , m_filter(NoFilter) {
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &FileSystemModel::watchDirIfRecursive);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &FileSystemModel::updateEntriesForDir);
    }

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    [[nodiscard]] QString path() const;
    void setPath(const QString& path);

    [[nodiscard]] bool recursive() const;
    void setRecursive(bool recursive);

    [[nodiscard]] bool watchChanges() const;
    void setWatchChanges(bool watchChanges);

    [[nodiscard]] bool showHidden() const;
    void setShowHidden(bool showHidden);

    [[nodiscard]] Filter filter() const;
    void setFilter(Filter filter);

    [[nodiscard]] QList<FileSystemEntry*> entries() const;

signals:
    void pathChanged();
    void recursiveChanged();
    void watchChangesChanged();
    void showHiddenChanged();
    void filterChanged();
    void entriesChanged();

    void added(const FileSystemEntry* entry);
    void removed(const QString& path);

private:
    QDir m_dir;
    QFileSystemWatcher m_watcher;
    QList<FileSystemEntry*> m_entries;
    QHash<QString, QFuture<QPair<QSet<QString>, QSet<QString>>>> m_futures;

    QString m_path;
    bool m_recursive;
    bool m_watchChanges;
    bool m_showHidden;
    Filter m_filter;

    void watchDirIfRecursive(const QString& path);
    void update();
    void updateWatcher();
    void updateEntries();
    void updateEntriesForDir(const QString& dir);
    void applyChanges(const QSet<QString>& removedPaths, const QSet<QString>& addedPaths);
    [[nodiscard]] static bool compareEntries(const FileSystemEntry* a, const FileSystemEntry* b);
};

} // namespace caelestia
