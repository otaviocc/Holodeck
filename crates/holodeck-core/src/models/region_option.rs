/// A human-readable Region for the TUI's launch-region picker — the same
/// concept as Settings → General → Language & Region → Region on a real
/// device, e.g. "Brazil" → `BR`. The table lists common App Store
/// territories rather than every ISO 3166-1 code. The CLI's `--region` flag
/// takes a raw code and does not read this table.
///
/// Distinct from `holodeck location` (GPS coordinates): "Region" here is a
/// storefront/locale setting, not a physical place.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RegionOption {
    pub display_name: &'static str,
    pub region_code: &'static str,
}

impl RegionOption {
    pub const ALL: &'static [RegionOption] = &[
        RegionOption { display_name: "United States", region_code: "US" },
        RegionOption { display_name: "United Kingdom", region_code: "GB" },
        RegionOption { display_name: "Canada", region_code: "CA" },
        RegionOption { display_name: "Australia", region_code: "AU" },
        RegionOption { display_name: "New Zealand", region_code: "NZ" },
        RegionOption { display_name: "Ireland", region_code: "IE" },
        RegionOption { display_name: "India", region_code: "IN" },
        RegionOption { display_name: "Brazil", region_code: "BR" },
        RegionOption { display_name: "Mexico", region_code: "MX" },
        RegionOption { display_name: "Argentina", region_code: "AR" },
        RegionOption { display_name: "Chile", region_code: "CL" },
        RegionOption { display_name: "Colombia", region_code: "CO" },
        RegionOption { display_name: "Portugal", region_code: "PT" },
        RegionOption { display_name: "Spain", region_code: "ES" },
        RegionOption { display_name: "France", region_code: "FR" },
        RegionOption { display_name: "Germany", region_code: "DE" },
        RegionOption { display_name: "Austria", region_code: "AT" },
        RegionOption { display_name: "Switzerland", region_code: "CH" },
        RegionOption { display_name: "Italy", region_code: "IT" },
        RegionOption { display_name: "Netherlands", region_code: "NL" },
        RegionOption { display_name: "Belgium", region_code: "BE" },
        RegionOption { display_name: "Sweden", region_code: "SE" },
        RegionOption { display_name: "Norway", region_code: "NO" },
        RegionOption { display_name: "Denmark", region_code: "DK" },
        RegionOption { display_name: "Finland", region_code: "FI" },
        RegionOption { display_name: "Poland", region_code: "PL" },
        RegionOption { display_name: "Czechia", region_code: "CZ" },
        RegionOption { display_name: "Hungary", region_code: "HU" },
        RegionOption { display_name: "Romania", region_code: "RO" },
        RegionOption { display_name: "Greece", region_code: "GR" },
        RegionOption { display_name: "Turkey", region_code: "TR" },
        RegionOption { display_name: "Russia", region_code: "RU" },
        RegionOption { display_name: "Ukraine", region_code: "UA" },
        RegionOption { display_name: "Israel", region_code: "IL" },
        RegionOption { display_name: "United Arab Emirates", region_code: "AE" },
        RegionOption { display_name: "Saudi Arabia", region_code: "SA" },
        RegionOption { display_name: "South Africa", region_code: "ZA" },
        RegionOption { display_name: "Japan", region_code: "JP" },
        RegionOption { display_name: "South Korea", region_code: "KR" },
        RegionOption { display_name: "China", region_code: "CN" },
        RegionOption { display_name: "Hong Kong", region_code: "HK" },
        RegionOption { display_name: "Taiwan", region_code: "TW" },
        RegionOption { display_name: "Singapore", region_code: "SG" },
        RegionOption { display_name: "Indonesia", region_code: "ID" },
        RegionOption { display_name: "Vietnam", region_code: "VN" },
        RegionOption { display_name: "Thailand", region_code: "TH" },
    ];
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_entry_has_a_non_empty_display_name_and_code() {
        for region in RegionOption::ALL {
            assert!(!region.display_name.is_empty());
            assert!(!region.region_code.is_empty());
        }
    }

    #[test]
    fn region_codes_are_unique() {
        let mut codes: Vec<&str> = RegionOption::ALL.iter().map(|r| r.region_code).collect();
        codes.sort_unstable();
        codes.dedup();
        assert_eq!(codes.len(), RegionOption::ALL.len());
    }
}
