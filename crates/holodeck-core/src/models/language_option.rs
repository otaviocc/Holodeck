/// A human-readable language/region pairing for the TUI's launch-language
/// picker, e.g. "Portuguese (Brazil)" → `pt-BR`. The table lists common
/// languages and regional variants rather than every BCP-47 tag iOS
/// recognizes. The CLI's `--language` flag takes a raw tag and does not read
/// this table.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LanguageOption {
    pub display_name: &'static str,
    pub bcp47: &'static str,
}

impl LanguageOption {
    pub const ALL: &'static [LanguageOption] = &[
        LanguageOption { display_name: "English (US)", bcp47: "en-US" },
        LanguageOption { display_name: "English (UK)", bcp47: "en-GB" },
        LanguageOption { display_name: "English (Australia)", bcp47: "en-AU" },
        LanguageOption { display_name: "English (Canada)", bcp47: "en-CA" },
        LanguageOption { display_name: "English (India)", bcp47: "en-IN" },
        LanguageOption { display_name: "Spanish (Spain)", bcp47: "es-ES" },
        LanguageOption { display_name: "Spanish (Mexico)", bcp47: "es-MX" },
        LanguageOption { display_name: "Spanish (Latin America)", bcp47: "es-419" },
        LanguageOption { display_name: "Portuguese (Brazil)", bcp47: "pt-BR" },
        LanguageOption { display_name: "Portuguese (Portugal)", bcp47: "pt-PT" },
        LanguageOption { display_name: "French (France)", bcp47: "fr-FR" },
        LanguageOption { display_name: "French (Canada)", bcp47: "fr-CA" },
        LanguageOption { display_name: "German (Germany)", bcp47: "de-DE" },
        LanguageOption { display_name: "German (Austria)", bcp47: "de-AT" },
        LanguageOption { display_name: "Italian (Italy)", bcp47: "it-IT" },
        LanguageOption { display_name: "Dutch (Netherlands)", bcp47: "nl-NL" },
        LanguageOption { display_name: "Russian", bcp47: "ru-RU" },
        LanguageOption { display_name: "Ukrainian", bcp47: "uk-UA" },
        LanguageOption { display_name: "Polish", bcp47: "pl-PL" },
        LanguageOption { display_name: "Czech", bcp47: "cs-CZ" },
        LanguageOption { display_name: "Slovak", bcp47: "sk-SK" },
        LanguageOption { display_name: "Hungarian", bcp47: "hu-HU" },
        LanguageOption { display_name: "Romanian", bcp47: "ro-RO" },
        LanguageOption { display_name: "Greek", bcp47: "el-GR" },
        LanguageOption { display_name: "Turkish", bcp47: "tr-TR" },
        LanguageOption { display_name: "Swedish", bcp47: "sv-SE" },
        LanguageOption { display_name: "Norwegian Bokmål", bcp47: "nb-NO" },
        LanguageOption { display_name: "Danish", bcp47: "da-DK" },
        LanguageOption { display_name: "Finnish", bcp47: "fi-FI" },
        LanguageOption { display_name: "Croatian", bcp47: "hr-HR" },
        LanguageOption { display_name: "Arabic", bcp47: "ar-SA" },
        LanguageOption { display_name: "Hebrew", bcp47: "he-IL" },
        LanguageOption { display_name: "Hindi", bcp47: "hi-IN" },
        LanguageOption { display_name: "Thai", bcp47: "th-TH" },
        LanguageOption { display_name: "Vietnamese", bcp47: "vi-VN" },
        LanguageOption { display_name: "Indonesian", bcp47: "id-ID" },
        LanguageOption { display_name: "Japanese", bcp47: "ja-JP" },
        LanguageOption { display_name: "Korean", bcp47: "ko-KR" },
        LanguageOption { display_name: "Chinese (Simplified)", bcp47: "zh-Hans" },
        LanguageOption { display_name: "Chinese (Traditional)", bcp47: "zh-Hant" },
    ];
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_entry_has_a_non_empty_display_name_and_tag() {
        for language in LanguageOption::ALL {
            assert!(!language.display_name.is_empty());
            assert!(!language.bcp47.is_empty());
        }
    }

    #[test]
    fn bcp47_tags_are_unique() {
        let mut tags: Vec<&str> = LanguageOption::ALL.iter().map(|l| l.bcp47).collect();
        tags.sort_unstable();
        tags.dedup();
        assert_eq!(tags.len(), LanguageOption::ALL.len());
    }
}
