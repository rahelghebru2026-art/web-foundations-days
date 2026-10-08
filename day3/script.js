let notes = [
  { id: 1, text: "Buy milk and bread", category: "personal" },
  { id: 2, text: "Finish the Day 3 assignment", category: "study" },
  { id: 3, text: "Email the project report to Grace", category: "work" },
  { id: 4, text: "Revise JavaScript arrays", category: "study" },
  { id: 5, text: "Call mum", category: "personal" },
];

function searchNotes(word) {
  return notes.filter(note =>
    note.text.toLowerCase().includes(word.toLowerCase())
  );
}

function longestNote() {
  if (notes.length === 0) {
    return null;
  }

  return notes.reduce((longest, note) => {
    if (note.text.length > longest.text.length) {
      return note;
    }

    return longest;
  });
}

function countByCategory() {
  return notes.reduce((counts, note) => {
    counts[note.category] = (counts[note.category] || 0) + 1;
    return counts;
  }, {});
}

function getSummary() {
  const counts = countByCategory();

  return `${notes.length} notes: ${counts.personal || 0} personal, ${counts.work || 0} work, ${counts.study || 0} study.`;
}

function normalizeText(text) {
  return text.trim().replace(/\s+/g, " ").toLowerCase();
}

function isDuplicate(text) {
  const normalizedText = normalizeText(text);

  return notes.some(note =>
    normalizeText(note.text) === normalizedText
  );
}

function addNote(text, category) {
  if (text.trim().length < 1 || text.length > 200) {
    console.log("Note must be between 1 and 200 characters.");
    return false;
  }

  if (!["personal", "work", "study"].includes(category)) {
    console.log("Invalid category.");
    return false;
  }

  if (isDuplicate(text)) {
    console.log("Duplicate note. Note was not added.");
    return false;
  }

  const newNote = {
    id: notes.length + 1,
    text: text,
    category: category
  };

  notes.push(newNote);

  return true;
}