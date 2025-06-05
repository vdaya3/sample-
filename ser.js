const express = require('express');
const cors = require('cors');
const Database = require('better-sqlite3');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../frontend')));

const db = new Database('database.db');

// Create table with svs column if not exists
db.prepare(`
  CREATE TABLE IF NOT EXISTS radar (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    quadrant TEXT NOT NULL,
    ring TEXT NOT NULL,
    description TEXT,
    svs TEXT
  )
`).run();

// Get all radar entries
app.get('/api/data', (req, res) => {
  const rows = db.prepare('SELECT * FROM radar').all();
  res.json(rows);
});

// Save radar entries (replace all)
app.post('/api/data', (req, res) => {
  const items = req.body;
  const deleteStmt = db.prepare('DELETE FROM radar');
  const insertStmt = db.prepare('INSERT INTO radar (name, quadrant, ring, description, svs) VALUES (?, ?, ?, ?, ?)');

  const insertMany = db.transaction((rows) => {
    deleteStmt.run();
    for (const row of rows) {
      insertStmt.run(row.name, row.quadrant, row.ring, row.description || '', row.svs || '');
    }
  });

  try {
    insertMany(items);
    res.sendStatus(200);
  } catch (err) {
    console.error(err);
    res.status(500).send('Failed to save data');
  }
});

const PORT = 3000;
app.listen(PORT, () => console.log(`Server listening on http://localhost:${PORT}`));