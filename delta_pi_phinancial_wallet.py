import os
import sqlite3
from datetime import datetime

# Directory for output files
OUTPUT_DIR = "wallet_output"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def log_disco(message):
    """Log transaction details to wallet_log.txt."""
    with open(f"{OUTPUT_DIR}/wallet_log.txt", "a") as f:
        f.write(f"{datetime.now().isoformat()}: {message}\n")

def init_wallet_db():
    """Initialize the SQLite database for wallet storage."""
    conn = sqlite3.connect("aethermind.db")
    c = conn.cursor()
    c.execute("CREATE TABLE IF NOT EXISTS wallet (id_hash TEXT PRIMARY KEY, aeth REAL, nft_count INTEGER, timestamp TEXT)")
    conn.commit()
    conn.close()

def add_to_wallet(id_hash, aeth, nft_count):
    """Add or update wallet balance for a given ID hash."""
    conn = sqlite3.connect("aethermind.db")
    c = conn.cursor()
    c.execute("INSERT OR REPLACE INTO wallet (id_hash, aeth, nft_count, timestamp) VALUES (?, ?, ?, ?)",
              (id_hash, aeth, nft_count, datetime.now().isoformat()))
    conn.commit()
    log_disco(f"Added: AETH {aeth}, NFTs {nft_count} for ID {id_hash}")
    conn.close()

def get_wallet_balance(id_hash):
    """Retrieve current balance for a given ID hash."""
    conn = sqlite3.connect("aethermind.db")
    c = conn.cursor()
    c.execute("SELECT aeth, nft_count FROM wallet WHERE id_hash = ?", (id_hash,))
    result = c.fetchone()
    conn.close()
    return result if result else (0.0, 0)

def main():
    """Main function to process wallet updates from coherence_log.txt."""
    init_wallet_db()
    id_hash = None
    aeth = 0.0
    nft_count = 0

    # Read data from coherence_log.txt
    log_path = os.path.join("coherence_output", "coherence_log.txt")
    if os.path.exists(log_path):
        with open(log_path, "r") as f:
            for line in f:
                if "Identity Hash:" in line:
                    id_hash = line.split("Identity Hash:")[1].strip()  # Match exact log format
                if "AETH Minted:" in line:
                    aeth = float(line.split("AETH Minted:")[1].strip())
                if "NFTs:" in line:  # Placeholder for future NFT support
                    nft_count = int(line.split("NFTs:")[1].strip())

    # Fallback if no data found
    if not id_hash or aeth is None:
        id_hash = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
        log_disco("Warning: No valid log data, using fallback ID and zero balance.")

    # Ensure minimum values
    aeth = max(aeth, 0.0)
    nft_count = max(nft_count, 0)

    # Update wallet
    add_to_wallet(id_hash, aeth, nft_count)

    # Retrieve and display balance
    balance_aeth, balance_nft = get_wallet_balance(id_hash)
    with open(f"{OUTPUT_DIR}/wallet_balance.txt", "w") as f:
        f.write(f"ID: {id_hash}\nAETH: {balance_aeth}\nNFTs: {balance_nft}\nTimestamp: {datetime.now().isoformat()}\n")
    log_disco(f"Balance updated: AETH {balance_aeth}, NFTs {balance_nft} for ID {id_hash}")

if __name__ == "__main__":
    main()
