var fs = require('fs');
var quotes = fs.readFileSync('excuses.txt').toString().split("\n");
var idx = process.argv.length >= 3 ? 
          process.argv[2] : Math.floor(Math.random() * quotes.length);
console.log(quotes[idx % quotes.length]);
