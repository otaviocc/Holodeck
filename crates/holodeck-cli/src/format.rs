use uuid::Uuid;

/// `Uuid::to_string()` is lowercase; Swift's `UUID.uuidString` is uppercase.
/// Match the Swift CLI's printed output exactly (plan §6.6).
pub fn udid(id: Uuid) -> String {
    id.to_string().to_uppercase()
}
