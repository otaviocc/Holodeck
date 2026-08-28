use uuid::Uuid;

/// Formats a UUID uppercase, the form holodeck prints.
pub fn udid(id: Uuid) -> String {
    id.to_string().to_uppercase()
}
