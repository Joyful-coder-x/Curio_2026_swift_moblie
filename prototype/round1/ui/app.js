const users = "ABCDEFGHIJ".split(""),
  names = [
    "Maya",
    "Jun",
    "Rae",
    "Leo",
    "Ana",
    "Sam",
    "Iris",
    "Uma",
    "Noa",
    "Kai",
  ];
const community = [
  ["Nora", "What’s blooming on your block?", 4], ["Eli", "Show me a rainy-day color.", 3],
  ["Kaia", "Where did the sunlight land?", 6], ["Sol", "What’s in your fruit bowl?", 2],
  ["Wren", "A window worth stopping for?", 8], ["Max", "Spot a yellow ride.", 5],
  ["Alma", "What did you bring home?", 7], ["Theo", "Find a flower facing the sun.", 9],
  ["Mei", "A quiet corner on your route?", 1], ["Lou", "What matches your umbrella?", 3],
  ["Ida", "A little detail on a doorstep?", 6], ["Noel", "Show me the morning market.", 2],
  ["Yuki", "A petal the color of honey?", 4], ["Ezra", "What catches your eye outside?", 5],
  ["Lena", "Where would you park your bike?", 1], ["Jules", "A snack for the walk home?", 7],
  ["Milo", "Whose window reflects the sky?", 8], ["Nia", "Which flower would you sketch?", 9],
  ["Finn", "What brightens a gray afternoon?", 3], ["Pia", "Something ripe in your kitchen?", 2],
  ["Otto", "Find a door with a story.", 6], ["Remy", "What makes you slow down?", 4],
  ["Tess", "A splash of yellow in traffic?", 5], ["Ari", "Something growing near home?", 9],
];
const name = (u) => names[users.indexOf(u)] ?? u,
  img = (n) => "assets/" + n + ".jpg",
  esc = (s) =>
    String(s).replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
const key = "curio.r1.ui.v2",
  now = () => Date.now() + db.offset,
  owner = (t) => t.photos[0].u,
  member = (t) => t.photos.some((p) => p.u === u),
  expired = (t) => now() >= t.end,
  full = (t) => t.photos.length === 9;
function seed() {
  const time = Date.now();
  return {
    offset: 0,
    follows: { B: ["A"] },
    threads: [
      {
        id: "YELLOW",
        token: "YELLOW-WALK",
        q: "Find something yellow.",
        private: false,
        end: time + 600000,
        photos: [{ u: "A", src: img(1) }],
        messages: [],
        grants: [],
        delivered: users.slice(1),
      },
      {
        id: "SUNLIGHT",
        token: "SUNLIGHT-WALK",
        q: "What caught the sunlight?",
        private: false,
        end: time - 86400000,
        photos: users.slice(0, 9).map((u, i) => ({ u, src: img(i + 1) })),
        messages: [{ u: "B", text: "I found mine on the walk home." }],
        grants: [],
        delivered: users.slice(1),
      },
    ],
  };
}
function seedCommunity(db, time) {
  const count = community.length;
  const threads = community.map(([author, q, image], i) => {
    const photos = Array.from({length: [1, 3, 5, 2, 4, 7][i % 6]}, (_, j) => ({
      u: community[(i + j) % count][0], src: img(1 + (image + j - 1) % 9)
    }));
    return {id: "WALK-" + time + "-" + i, token: crypto.randomUUID(), private: false,
      q, end: time + 600000 - i * 1000, photos, messages: [], grants: [], delivered: [...users]};
  });
  db.threads.push(...threads);
}
let db;
try {
  db = JSON.parse(localStorage.getItem(key));
} catch {}
db = db || seed();
if (!db.threads.some(t => t.id.startsWith("WALK-") && t.end > now())) seedCommunity(db, now());
let u = users.includes(sessionStorage.curioUser)
    ? sessionStorage.curioUser
    : "A",
  page = "home",
  tab = "Discover",
  id = "",
  draft = null,
  notice = "",
  chatOpen = false;
function save() {
  try {
    localStorage.setItem(key, JSON.stringify(db));
  } catch {
    notice =
      "Device storage unavailable. This session will continue in memory.";
  }
}
const follows = (a) => (db.follows[u] || []).includes(a),
  can = (t) =>
    !t.private || member(t) || follows(owner(t)) || t.grants.includes(u);
const chosen = () => db.threads.find((t) => t.id === id),
  button = (text, action, cls = "") =>
    '<button class="' +
    cls +
    '" onclick="' +
    action +
    '">' +
    esc(text) +
    "</button>";
function home() {
  page = "home";
  notice = "";
  render();
}
function openThread(k) {
  id = k;
  const t = chosen();
  if (!t || !can(t)) {
    notice = "Access unavailable.";
    page = "home";
  } else {
    page = expired(t) ? "journal" : "thread";
    notice = "";
    chatOpen = false;
  }
  render();
}
function redeem(code) {
  let t = db.threads.find((t) => t.token === code.trim());
  if (!t) {
    notice = "Invitation code not found.";
    render();
    return;
  }
  if (!t.grants.includes(u)) t.grants.push(u);
  save();
  openThread(t.id);
}
function compose(join = false) {
  draft = { join, src: "", confirmed: false, q: "", private: false };
  page = "form";
  notice = "";
  render();
}
function follow(a) {
  db.follows[u] = follows(a)
    ? db.follows[u].filter((x) => x !== a)
    : [...(db.follows[u] || []), a];
  save();
  render();
}
function publish() {
  if (!draft?.confirmed) return;
  const t = chosen();
  if (draft.join) {
    if (!t || !can(t) || expired(t) || full(t) || member(t)) {
      notice = "Joining is unavailable. Your draft is still here.";
      render();
      return;
    }
    t.photos.push({ u, src: draft.src, at: now(), color: draft.color });
    t.lastPhotoAt = now();
    id = t.id;
  } else {
    if (!draft.q.trim()) return;
    if (
      db.threads.some(
        (t) =>
          owner(t) === u &&
          new Date(t.end - 600000).toISOString().slice(0, 10) ===
            new Date(now()).toISOString().slice(0, 10),
      )
    ) {
      notice =
        "One invitation per day. Switch to another test account to publish.";
      render();
      return;
    }
    id = crypto.randomUUID().slice(0, 8).toUpperCase();
    db.threads.unshift({
      id,
      token: crypto.randomUUID(),
      q: draft.q.trim(),
      private: draft.private,
      end: now() + 600000,
      photos: [{ u, src: draft.src, at: now(), color: draft.color }],
      messages: [],
      grants: [],
      delivered: users.filter(
        (v) => v !== u && (!draft.private || (db.follows[v] || []).includes(u)),
      ),
    });
  }
  save();
  draft = null;
  openThread(id);
}
function send() {
  let t = chosen(),
    text = document.getElementById("msg").value.trim();
  if (text && member(t) && !expired(t)) {
    t.messages.push({ u, text, at: now() });
    save();
  }
  render();
}
async function pick(file) {
  if (!file) return;
  try {
    const bmp = await createImageBitmap(file),
      c = document.createElement("canvas"),
      scale = Math.min(1, 720 / Math.max(bmp.width, bmp.height));
    c.width = bmp.width * scale;
    c.height = bmp.height * scale;
    c.getContext("2d").drawImage(bmp, 0, 0, c.width, c.height);
    const pixel = c.getContext("2d").getImageData(Math.floor(c.width / 2), Math.floor(c.height / 2), 1, 1).data;
    draft.color = "#" + Array.from(pixel.slice(0, 3), v => v.toString(16).padStart(2, "0")).join("");
    draft.src = c.toDataURL("image/jpeg", 0.72);
    bmp.close();
    render();
  } catch {
    notice = "Choose a supported image or try a sample.";
    render();
  }
}
function state(t) {
  return expired(t)
    ? "Saved"
    : (full(t) ? "Full" : "Open") +
        " · " +
        Math.ceil((t.end - now()) / 60000) +
        " min left";
}
function events(t) {
  const start = t.end - 600000;
  const photos = t.photos.map((p, i) => ({
    ...p, at: p.at ?? start + i, label: i ? "joined the thread with a photo" : "started the thread"
  }));
  const messages = t.messages.map((m, i) => ({...m, at: m.at ?? start + photos.length + i}));
  return [...photos, ...messages].sort((a, b) => a.at - b.at);
}
function threadCover(t, caption = false) {
  const n = expired(t) ? 3 : t.photos.length === 1 ? 1 : t.photos.length <= 4 ? 2 : 3;
  const tones = ["#ca7a77","#ae9258","#c2a050","#cbb878","#7a7d7f","#b8861d","#d29020","#9e7952","#c3a455"];
  let ordered = t.photos;
  if (expired(t)) {
    const center = t.photos.find(p => p.u === u) || t.photos[0];
    ordered = t.photos.filter(p => p !== center);
    while (ordered.length < 8) ordered.push(null);
    ordered.splice(4, 0, center);
  }
  const cells = Array.from({length:n*n}, (_, i) => {
    if (ordered[i]) return '<img alt="" src="' + esc(ordered[i].src) + '">';
    if (expired(t)) return '<i class="empty-slot"></i>';
    const sample = t.photos[i % t.photos.length];
    const index = tones.findIndex((_, j) => sample.src === img(j+1));
    const tone = sample.color || tones[index] || "#dbc5aa";
    return '<i style="background:' + (/^#[0-9a-f]{6}$/i.test(tone) ? tone : "#dbc5aa") + '"></i>';
  });
  return '<span class="mini-print"><span class="mosaic" style="--cols:'+n+'">'+cells.join("")+'</span>' + (caption ? '<em>'+esc(t.q)+'</em>' : '') + '</span>';
}
let mineFilter = "All";
function collection(threads) {
  if (!threads.length) return "<small>No threads here yet.</small>";
  return '<div class="collection">' + threads.map(t => {
    const meta = tab === "Mine" ? (owner(t) === u ? "Created" : "Joined") : name(owner(t));
    const author = name(owner(t));
    const byline = tab === "Discover" ? `<span class="byline"><span class="initial" aria-hidden="true">${esc(author[0])}</span>${esc(author)}</span>` : "";
    return `<button class="print-card" onclick="openThread('${t.id}')">${threadCover(t, true)}${byline}<small>${tab === "Mine" ? meta + " · " : ""} ${t.photos.length}/9 · ${state(t)}</small></button>`;
  }).join("") + '</div>';
}
function mineView(list) {
  const active = list.filter(t => !expired(t)), saved = list.filter(expired);
  const visible = t => mineFilter === "All" || (owner(t) === u ? "Created" : "Joined") === mineFilter;
  return '<div class="profile-head"><h1>'+name(u)+'</h1><small>'+list.filter(t=>owner(t)===u).length+' created · '+list.filter(t=>owner(t)!==u).length+' joined · '+saved.length+' saved</small></div><div class="row">'+["All","Created","Joined"].map(x=>button(x,"mineFilter='"+x+"';render()",mineFilter===x?"on":"")).join("")+'</div><h2>Active</h2>'+collection(active.filter(visible).sort((a,b)=>a.end-b.end))+'<h2>Saved journals</h2>'+collection(saved.filter(visible).sort((a,b)=>b.end-a.end));
}
function inboxRows(list) {
  const rows = list.map(t => {
    const last = member(t) ? events(t).at(-1) : events(t)[0];
    const preview = member(t) ? name(last.u) + (last.src ? " " + last.label : " · " + last.text) : "Photo invitation from " + name(owner(t));
    return {t, preview, at:last.at};
  }).sort((a,b) => b.at - a.at);
  return rows.map(({t,preview,at}) => `<button class="conversation-row" onclick="openThread('${t.id}')">${threadCover(t)}<span><strong>${esc(t.q)}</strong><small>${esc(preview)}</small></span><time>${new Date(at).toLocaleTimeString([], {hour:"numeric",minute:"2-digit"})}</time></button>`).join("") || "<p>Your inbox is empty.</p>";
}
function timeline(t) {
  return events(t).map(e => {
    const author = name(e.u);
    if (e.src) return `<figure class="photo-event"><figcaption><b>${author}</b> ${e.label}:</figcaption><img src="${esc(e.src)}" alt="Photo by ${author}"></figure>`;
    return `<div class="bubble ${e.u === u ? "mine" : ""}"><small>${author}</small><p>${esc(e.text)}</p></div>`;
  }).join("");
}
function render() {
  let s = "",
    t = chosen();
  if ((page === "thread" || page === "journal") && (!t || !can(t)))
    page = "home";
  if (page === "thread" && expired(t)) page = "journal";
  if (page === "home") {
    let list = db.threads.filter(
      (t) =>
        can(t) &&
        (tab === "Mine"
          ? member(t)
          : tab === "Inbox"
            ? member(t) || t.delivered.includes(u)
            : !expired(t) && !full(t)),
    );
    if (tab === "Mine") s = mineView(list);
    else if (tab === "Inbox") s = "<h1>Inbox</h1>" + inboxRows(list);
    else s = "<h1>Discover</h1>" + collection(list);
    s +=
      '<details><summary>Open invitation code</summary><input id="code" placeholder="Invitation code">' +
      button("Open", "redeem(document.getElementById(\'code\').value)") +
      "</details>";
  }
  if (page === "form") {
    s =
      "<small>" +
      (draft.join ? "Reply to " + name(owner(t)) : "Create a thread") +
      "</small><h1>" +
      (draft.confirmed ? "Ready to send?" : "Choose your photo") +
      "</h1>";
    if (draft.src)
      s +=
        '<img class="hero" src="' +
        esc(draft.src) +
        '" alt="Photo for review">';
    if (!draft.confirmed) {
      s +=
        '<label class="upload">Take a photo<input type="file" capture="environment" accept="image/*" onchange="pick(this.files[0])"></label><label class="upload">Choose from library<input type="file" accept="image/*" onchange="pick(this.files[0])"></label><p>Or choose a sample</p><div class="strip">' +
        [1, 2, 3, 4]
          .map(
            (n) =>
              '<button onclick="draft.color=null;draft.src=img(' +
              n +
              ');render()"><img alt="Sample ' +
              n +
              '" src="' +
              img(n) +
              '"></button>',
          )
          .join("") +
        "</div>";
      if (draft.src)
        s += button(
          "Use this photo",
          "draft.confirmed=true;render()",
          "primary",
        );
    } else {
      s += button("Retake", "draft.confirmed=false;draft.src='';render()");
      if (!draft.join)
        s +=
          '<label for="q">What would you like to see?</label><input id="q" maxlength="140" value="' +
          esc(draft.q) +
          '" placeholder="Find something yellow." oninput="draft.q=this.value;document.getElementById(\'submit\').disabled=!this.value.trim()"><label>Audience</label><div class="row">' +
          [false, true]
            .map((p) =>
              button(
                p ? "Private" : "Public",
                "draft.private=" + p + ";render()",
                p === draft.private ? "on" : "",
              ),
            )
            .join("") +
          "</div><small>" +
          (draft.private
            ? "Followers receive it. Anyone signed in with the link can view."
            : "Delivered to every other test account.") +
          "</small>";
      else s += "<h2>" + esc(t.q) + "</h2>";
      s +=
        '<p>Once accepted, your photo is permanent.</p><button id="submit" class="primary" ' +
        (!draft.join && !draft.q.trim() ? "disabled" : "") +
        ' onclick="publish()">' +
        (draft.join ? "Send photo & join" : "Publish invitation") +
        "</button>";
    }
  }
  if (page === "thread" || page === "journal") {
    s =
      "<small>" +
      name(owner(t)) +
      " · " +
      (t.private ? "Private" : "Public") +
      "</small><h1>" +
      esc(t.q) +
      '</h1><span class="tag">' +
      state(t) +
      '</span> <span class="tag">' +
      t.photos.length +
      "/9 people</span>";
    if (page === "thread") {
      if (!member(t)) s +=
        '<div class="strip">' +
        t.photos
          .map(
            (p) =>
              '<img src="' + esc(p.src) + '" alt="' + name(p.u) + ' photo">',
          )
          .join("") +
        "</div>";
      if (!member(t) && !full(t))
        s += button("Add a photo", "compose(true)", "primary");
      if (full(t)) s += "<p>All nine places are filled.</p>";
    } else {
      let center = t.photos.find((p) => p.u === u) || t.photos[0],
        others = t.photos.filter((p) => p !== center);
      s +=
        '<div class="grid">' +
        Array.from({ length: 9 }, (_, i) => {
          let p = i === 4 ? center : others.shift();
          return p
            ? '<img src="' + esc(p.src) + '" alt="Photo by ' + name(p.u) + '">'
            : "<span></span>";
        }).join("") +
        '</div><h2>Contributors</h2><div class="row">' +
        t.photos
          .map((p) =>
            p.u === u
              ? "<b>" + name(u) + " (you)</b>"
              : button(
                  name(p.u) + (follows(p.u) ? " ✓" : " +"),
                  "follow('" + p.u + "')",
                ),
          )
          .join("") +
        "</div>";
    }
    if (member(t)) {
      if (page === "journal")
        s += button(
          chatOpen ? "Hide conversation" : "View conversation",
          "chatOpen=!chatOpen;render()",
        );
      if (page === "thread" || chatOpen) {
        s += '<div class="conversation-feed">' + timeline(t) + '</div>';
        if (page === "thread")
          s +=
            '<input id="msg" aria-label="Group message" placeholder="Message the group…">' +
            button("Send message", "send()");
        else s += "<small>Archived · Read only</small>";
      }
    }
    s +=
      "<details><summary>Share invitation</summary><p>Code <b>" +
      esc(t.token) +
      "</b></p>" +
      button("Copy link", "copyLink()") +
      "</details>";
  }
  const panel = document.getElementById("page");
  const route = [page, tab, id, u].join("/");
  if (panel.dataset.route !== route) panel.scrollTop = 0;
  panel.dataset.route = route;
  panel.innerHTML =
    s + '<p id="notice" role="status">' + esc(notice) + "</p>";
  document.getElementById("nav").innerHTML =
    ["Discover","Inbox","Mine"].map(x => button(x === "Discover" ? "Home" : x, "tab='"+x+"';home()",page === "home" && tab === x ? "selected-tab" : "")).join("") + button("+ New invitation", "compose()");
}
async function copyLink() {
  const link = location.href.split("#")[0] + "#invite=" + chosen().token;
  try {
    await navigator.clipboard.writeText(link);
    notice = "Link copied.";
  } catch {
    notice = "Share code: " + chosen().token;
  }
  render();
}
person.innerHTML = users
  .map((x) => '<option value="' + x + '">' + x + " · " + name(x) + "</option>")
  .join("");
save();
person.value = u;
person.onchange = () => {
  sessionStorage.curioUser = u = person.value;
  tab = "Discover";
  home();
};
advance.onclick = () => {
  db.offset += 600000;
  save();
  render();
};
reset.onclick = () => {
  db = seed();
  seedCommunity(db, now());
  save();
  tab = "Discover";
  home();
};
window.onhashchange = () => {
  if (location.hash.startsWith("#invite=")) redeem(location.hash.slice(8));
};
render();
window.onhashchange();
setInterval(() => {
  if (page === "thread" && expired(chosen())) render();
  else if (page === "thread")
    document.querySelector(".tag").textContent = state(chosen());
  else if (
    page === "home" &&
    !document.activeElement.matches("input,select,summary") &&
    !document.querySelector("details[open]")
  )
    render();
}, 10000);
