import * as fs from 'fs';
import * as path from 'path';

const filename = 'ztest/contract_addresses.txt';  // File to store name-contract pairs

// Function to read existing entries from the file
function readExistingEntries(file: string): string[] {
    if (fs.existsSync(file)) {
        const data = fs.readFileSync(file, 'utf8');
        return data.trim().split('\n').filter(Boolean);  // Return an array of non-empty lines
    }
    return [];
}

// Function to append new entries
function appendEntry(file: string, name: string, address: string): void {
    const entry = `${name}: ${address}`;
    const existingEntries = readExistingEntries(file);

    // Append only if this name-address pair does not already exist
    if (!existingEntries.includes(entry)) {
        existingEntries.push(entry);
        fs.writeFileSync(file, existingEntries.join('\n') + '\n', 'utf8');
    }
}

// Get the name and contract address from the command-line arguments
const name = process.argv[2];
const address = process.argv[3];

// Append the new entry
appendEntry(filename, name, address);
