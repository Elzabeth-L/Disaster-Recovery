const form = document.querySelector("#note-form");
const notesElement = document.querySelector("#notes");
const statusElement = document.querySelector("#form-status");

function noteCard(note) {
  const article = document.createElement("article");
  const heading = document.createElement("h3");
  const content = document.createElement("p");
  const metadata = document.createElement("small");
  const remove = document.createElement("button");

  heading.textContent = note.title;
  content.textContent = note.content;
  metadata.textContent = new Date(note.created_at).toLocaleString();
  remove.textContent = "Delete";
  remove.className = "delete";
  remove.addEventListener("click", async () => {
    const response = await fetch(`/api/notes/${note.id}`, { method: "DELETE" });
    if (response.ok) await loadNotes();
  });

  article.append(heading, content, metadata, remove);
  return article;
}

async function loadNotes() {
  const response = await fetch("/api/notes");
  if (!response.ok) {
    notesElement.textContent = "Notes are temporarily unavailable.";
    return;
  }
  const notes = await response.json();
  notesElement.replaceChildren(...notes.map(noteCard));
  if (notes.length === 0) notesElement.textContent = "No notes yet.";
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  statusElement.textContent = "Saving?";
  const formData = new FormData(form);
  const response = await fetch("/api/notes", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: formData.get("title"), content: formData.get("content") }),
  });
  if (!response.ok) {
    const body = await response.json();
    statusElement.textContent = body.error || "Could not save the note.";
    return;
  }
  form.reset();
  statusElement.textContent = "Saved.";
  await loadNotes();
});

loadNotes();
