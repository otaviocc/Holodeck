#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrivacyAction {
    Grant,
    Revoke,
    Reset,
}

impl PrivacyAction {
    pub const ALL: [PrivacyAction; 3] = [PrivacyAction::Grant, PrivacyAction::Revoke, PrivacyAction::Reset];

    pub fn raw_value(self) -> &'static str {
        match self {
            PrivacyAction::Grant => "grant",
            PrivacyAction::Revoke => "revoke",
            PrivacyAction::Reset => "reset",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrivacyPermission {
    All,
    Calendar,
    ContactsLimited,
    Contacts,
    Location,
    LocationAlways,
    PhotosAdd,
    Photos,
    MediaLibrary,
    Microphone,
    Motion,
    Reminders,
    Siri,
}

impl PrivacyPermission {
    pub const ALL: [PrivacyPermission; 13] = [
        PrivacyPermission::All,
        PrivacyPermission::Calendar,
        PrivacyPermission::ContactsLimited,
        PrivacyPermission::Contacts,
        PrivacyPermission::Location,
        PrivacyPermission::LocationAlways,
        PrivacyPermission::PhotosAdd,
        PrivacyPermission::Photos,
        PrivacyPermission::MediaLibrary,
        PrivacyPermission::Microphone,
        PrivacyPermission::Motion,
        PrivacyPermission::Reminders,
        PrivacyPermission::Siri,
    ];

    pub fn raw_value(self) -> &'static str {
        match self {
            PrivacyPermission::All => "all",
            PrivacyPermission::Calendar => "calendar",
            PrivacyPermission::ContactsLimited => "contacts-limited",
            PrivacyPermission::Contacts => "contacts",
            PrivacyPermission::Location => "location",
            PrivacyPermission::LocationAlways => "location-always",
            PrivacyPermission::PhotosAdd => "photos-add",
            PrivacyPermission::Photos => "photos",
            PrivacyPermission::MediaLibrary => "media-library",
            PrivacyPermission::Microphone => "microphone",
            PrivacyPermission::Motion => "motion",
            PrivacyPermission::Reminders => "reminders",
            PrivacyPermission::Siri => "siri",
        }
    }
}
