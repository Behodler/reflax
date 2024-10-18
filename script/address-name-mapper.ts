import * as fs from 'fs';
import * as path from 'path';

const filename = 'script/addresses.json';  // File to store name-contract pairs

interface dictionary {
    [key: string]: string
}

// Function to read existing entries from the file
function readExistingEntries(file: string): dictionary {
    let parsedObject = {}
    if (fs.existsSync(file)) {
        const data = fs.readFileSync(file, 'utf8');

        try {


            parsedObject = JSON.parse(data);
        } catch { }
    }
    return parsedObject;
}

// Function to append new entries
function appendEntry(file: string, name: string, address: string): void {
    const entry = `${name}: ${address}`;
    const existingEntries = readExistingEntries(file);
    existingEntries[name] = address;

    fs.writeFileSync(file, JSON.stringify(existingEntries, null, 4), "utf-8");

}

// Get the name and contract address from the command-line arguments
const name = process.argv[2];
const address = process.argv[3];

// Append the new entry
appendEntry(filename, name, address);
