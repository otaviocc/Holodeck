BINARY := holodeck

.PHONY: build run test clean fmt install uninstall

build:
	cargo build --release

run:
	cargo run --release -p holodeck-simctl -- tui

test:
	cargo test

clean:
	cargo clean

fmt:
	cargo fmt

install:
	cargo install --path crates/holodeck-cli --locked --force

uninstall:
	cargo uninstall holodeck-simctl
