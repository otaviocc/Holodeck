BINARY := holodeck

.PHONY: build run test clean fmt

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
