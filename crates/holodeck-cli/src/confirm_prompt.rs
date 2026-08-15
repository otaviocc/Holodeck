use std::io::Write;

/// Prompts to stderr, reads from stdin; default is No, EOF is No.
pub fn confirm(message: &str, skip: bool) -> bool {
    if skip {
        return true;
    }
    eprint!("{message} [y/N] ");
    let _ = std::io::stderr().flush();
    let mut line = String::new();
    if std::io::stdin().read_line(&mut line).is_err() {
        return false;
    }
    if line.is_empty() {
        return false;
    }
    let trimmed = line.trim().to_lowercase();
    trimmed == "y" || trimmed == "yes"
}
