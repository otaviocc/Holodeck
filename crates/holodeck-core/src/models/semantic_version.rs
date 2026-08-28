use std::cmp::Ordering;
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct SemanticVersion {
    pub major: i64,
    pub minor: i64,
    pub patch: i64,
}

impl SemanticVersion {
    pub fn new(major: i64, minor: i64, patch: i64) -> Self {
        Self { major, minor, patch }
    }

    /// Lenient parse: requires a parseable major component; an unparseable
    /// minor or patch becomes 0.
    pub fn parse(string: &str) -> Option<Self> {
        let parts: Vec<&str> = string.split('.').collect();
        let major = parts.first()?.parse::<i64>().ok()?;
        let minor = parts.get(1).and_then(|p| p.parse::<i64>().ok()).unwrap_or(0);
        let patch = parts.get(2).and_then(|p| p.parse::<i64>().ok()).unwrap_or(0);
        Some(Self { major, minor, patch })
    }
}

impl PartialOrd for SemanticVersion {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for SemanticVersion {
    fn cmp(&self, other: &Self) -> Ordering {
        self.major.cmp(&other.major).then(self.minor.cmp(&other.minor)).then(self.patch.cmp(&other.patch))
    }
}

impl fmt::Display for SemanticVersion {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.patch == 0 {
            write!(f, "{}.{}", self.major, self.minor)
        } else {
            write!(f, "{}.{}.{}", self.major, self.minor, self.patch)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_major_minor_patch() {
        assert_eq!(SemanticVersion::parse("18.4.1"), Some(SemanticVersion::new(18, 4, 1)));
    }

    #[test]
    fn defaults_missing_components_to_zero() {
        assert_eq!(SemanticVersion::parse("18"), Some(SemanticVersion::new(18, 0, 0)));
    }

    #[test]
    fn rejects_unparseable_major() {
        assert_eq!(SemanticVersion::parse("x.4"), None);
    }

    #[test]
    fn display_omits_zero_patch() {
        assert_eq!(SemanticVersion::new(26, 4, 0).to_string(), "26.4");
        assert_eq!(SemanticVersion::new(26, 4, 1).to_string(), "26.4.1");
    }

    #[test]
    fn orders_by_major_then_minor_then_patch() {
        assert!(SemanticVersion::new(18, 0, 0) < SemanticVersion::new(18, 1, 0));
        assert!(SemanticVersion::new(17, 9, 9) < SemanticVersion::new(18, 0, 0));
    }
}
