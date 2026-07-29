#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def xor_encrypt(plain_bytes: bytes, password: str) -> str:
    password_bytes = password.encode("utf-8")
    out = bytearray(len(plain_bytes))
    for i, b in enumerate(plain_bytes):
        password_byte = password_bytes[i % len(password_bytes)]
        key = (password_byte + i + (i % 7)) % 256
        out[i] = b ^ key
    return out.hex().upper()


def sha256_hex(value: str) -> str:
    import hashlib
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description="Encrypt a letter and save JSON output.")
    parser.add_argument("--password", default="2706", help="Password to use for encryption")
    parser.add_argument("--source", default="letter-source.txt", help="Source text file")
    parser.add_argument("--output", default="encrypted-letter.json", help="Output JSON file")
    args = parser.parse_args()

    source_path = Path(args.source)
    output_path = Path(args.output)

    plain = source_path.read_text(encoding="utf-8")
    ciphertext = xor_encrypt(plain.encode("utf-8"), args.password)
    password_hash = sha256_hex(args.password)

    result = {
        "passwordHash": password_hash.lower(),
        "ciphertext": ciphertext,
    }

    output_path.write_text(json.dumps(result, separators=(",", ":")), encoding="utf-8")
    print(f"Updated {output_path} using password {args.password}")


if __name__ == "__main__":
    main()
