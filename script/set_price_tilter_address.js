const fs = require('fs');

async function main() {
    // Read addresses.json
    const output = JSON.parse(fs.readFileSync('./addresses.json', 'utf-8'));
    const priceTilter = output["priceTilter"]
    console.log(priceTilter)
}
main().catch(console.error);
