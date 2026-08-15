use std::io::Write;

use crate::config_resolver::ConfigResolver;

pub const CAPACITY: usize = 20;

const HISTORY_FILE_NAME: &str = "url-history.json";

/// Pure list-update logic, kept separate from disk I/O so it can be tested
/// without a filesystem.
pub fn updated(history: &[String], url: &str) -> Vec<String> {
    let mut list: Vec<String> = history.iter().filter(|existing| existing.as_str() != url).cloned().collect();
    list.insert(0, url.to_string());
    list.truncate(CAPACITY);
    list
}

pub struct UrlHistoryStore {
    path: std::path::PathBuf,
}

impl UrlHistoryStore {
    pub fn new(resolver: &ConfigResolver) -> Self {
        Self { path: resolver.file(HISTORY_FILE_NAME) }
    }

    /// Load failures (missing file, malformed JSON) degrade silently to `[]`,
    /// matching the Swift `URLHistoryStore.live().load`.
    pub fn load(&self) -> Vec<String> {
        std::fs::read(&self.path).ok().and_then(|data| serde_json::from_slice(&data).ok()).unwrap_or_default()
    }

    pub fn record(&self, url: &str) -> std::io::Result<Vec<String>> {
        let list = updated(&self.load(), url);
        if let Some(parent) = self.path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let json = serde_json::to_string_pretty(&list)?;
        let parent = self.path.parent().unwrap_or_else(|| std::path::Path::new("."));
        let mut tmp = tempfile::NamedTempFile::new_in(parent)?;
        tmp.write_all(json.as_bytes())?;
        tmp.persist(&self.path).map_err(|err| err.error)?;
        Ok(list)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn inserts_new_url_at_front() {
        let history = vec!["https://b.com".to_string()];
        assert_eq!(updated(&history, "https://a.com"), vec!["https://a.com", "https://b.com"]);
    }

    #[test]
    fn deduplicates_and_moves_existing_url_to_front() {
        let history = vec!["https://a.com".to_string(), "https://b.com".to_string()];
        assert_eq!(updated(&history, "https://b.com"), vec!["https://b.com", "https://a.com"]);
    }

    #[test]
    fn truncates_at_capacity() {
        let history: Vec<String> = (0..CAPACITY).map(|i| format!("https://{i}.com")).collect();
        let result = updated(&history, "https://new.com");
        assert_eq!(result.len(), CAPACITY);
        assert_eq!(result[0], "https://new.com");
    }

    #[test]
    fn missing_file_loads_as_empty() {
        let dir = tempfile::tempdir().unwrap();
        let resolver = ConfigResolver::mock(dir.path());
        assert!(UrlHistoryStore::new(&resolver).load().is_empty());
    }

    #[test]
    fn record_persists_and_reloads() {
        let dir = tempfile::tempdir().unwrap();
        let resolver = ConfigResolver::mock(dir.path());
        let store = UrlHistoryStore::new(&resolver);
        store.record("https://apple.com").unwrap();
        assert_eq!(store.load(), vec!["https://apple.com"]);
    }
}
