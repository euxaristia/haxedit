#define O_RDONLY  0x0000
#define O_WRONLY  0x0001
#define O_RDWR    0x0002
#define O_CREAT   0x0040
#define O_TRUNC   0x0200

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

#define K_ESC 27
#define K_ARROW_LEFT  1000
#define K_ARROW_RIGHT 1001
#define K_ARROW_UP    1002
#define K_ARROW_DOWN  1003
#define K_PAGE_UP     1004
#define K_PAGE_DOWN   1005
#define K_HOME        1006
#define K_END         1007

#define PANE_HEX   0
#define PANE_ASCII 1

#define TIOCGWINSZ 0x5413
#define UNDO_MAX 256
#define UNDO_DATA_MAX 4096

#define UNDO_OP_OVERWRITE 1
#define UNDO_OP_INSERT    2

extern "c" I32 open(U8 *name, I32 flags, ...);
extern "c" I32 close(I32 fd);
extern "c" I64 read(I32 fd, U0 *buf, U64 nbyte);
extern "c" I64 write(I32 fd, U0 *buf, U64 nbyte);
extern "c" I64 lseek(I32 fd, I64 offset, I32 whence);
extern "c" I32 ioctl(I32 fd, U64 request, ...);
extern "c" I64 strlen(U8 *s);
extern "c" I32 strncmp(U8 *s1, U8 *s2, U64 n);
extern "c" U8 *strcpy(U8 *dst, U8 *src);
extern "c" U0 *malloc(U64 size);
extern "c" U0 *realloc(U0 *ptr, U64 size);
extern "c" U0 free(U0 *ptr);
extern "c" U8 *strdup(U8 *s);
extern "c" I64 snprintf(I8 *buf, U64 len, I8 *fmt, ...);
extern "c" I64 system(U8 *cmd);
extern "c" U0 *memset(U0 *ptr, I32 value, U64 num);
extern "c" U0 *memcpy(U0 *dst, U0 *src, U64 n);
extern "c" U0 *memmove(U0 *dst, U0 *src, U64 n);
extern "c" I32 strcmp(U8 *s1, U8 *s2);
extern "c" U0 exit(I32 code);
extern "c" I32 isatty(I32 fd);
extern "c" I64 strtoll(U8 *nptr, U8 **endptr, I64 base);

class WinSize
{
  U16 row;
  U16 col;
  U16 xpixel;
  U16 ypixel;
};

class UndoEntry
{
  I64 op;
  I64 pos;
  I64 old_len;
  I64 new_len;
  U8 old_data[UNDO_DATA_MAX];
  U8 new_data[UNDO_DATA_MAX];
};

class Editor
{
  U8 *path;
  U8 *buf;
  I64 len;
  I64 cap;
  I64 cur;
  I64 top;
  I64 rows;
  I64 cols;
  I64 bpl;
  Bool bpl_auto;
  I64 pane;
  I64 hex_half;
  Bool readonly;
  Bool mark_on;
  I64 mark_pos;
  Bool dirty;
  Bool quit_confirm;
  U8 *clip;
  I64 clip_len;
  I64 clip_cap;
  UndoEntry undo[UNDO_MAX];
  I64 undo_len;
  I64 undo_idx;
  U8 search[256];
  I64 search_len;
  U8 status[256];
};

Editor *_G(U0)
{
  static Editor g_state;
  return &g_state;
}

U0 KeepVisible();
U0 SetStatus(U8 *msg);
U0 InsertBytes(I64 pos, U8 *data, I64 n, Bool track_undo);
U0 SetByteAt(I64 idx, U8 b, Bool track_undo);

U0 PushUndoOverwrite(I64 pos, U8 old_b, U8 new_b)
{
  Editor *g = _G();
  UndoEntry *e;
  I64 i;

  if (old_b == new_b) return;

  if (g->undo_idx < g->undo_len) {
    g->undo_len = g->undo_idx;
  }

  if (g->undo_len >= UNDO_MAX) {
    for (i = 1; i < g->undo_len; ++i) {
      memcpy(&g->undo[i - 1], &g->undo[i], sizeof(UndoEntry));
    }
    g->undo_len--;
    if (g->undo_idx > 0) g->undo_idx--;
  }

  e = &g->undo[g->undo_len++];
  e->op = UNDO_OP_OVERWRITE;
  e->pos = pos;
  e->old_len = 1;
  e->new_len = 1;
  e->old_data[0] = old_b;
  e->new_data[0] = new_b;
  g->undo_idx = g->undo_len;
}

U0 PushUndoInsert(I64 pos, U8 *bytes, I64 n)
{
  Editor *g = _G();
  UndoEntry *e;
  I64 i;

  if (n <= 0) return;
  if (n > UNDO_DATA_MAX) {
    SetStatus("undo: insert too large to track");
    return;
  }

  if (g->undo_idx < g->undo_len) {
    g->undo_len = g->undo_idx;
  }

  if (g->undo_len >= UNDO_MAX) {
    for (i = 1; i < g->undo_len; ++i) {
      memcpy(&g->undo[i - 1], &g->undo[i], sizeof(UndoEntry));
    }
    g->undo_len--;
    if (g->undo_idx > 0) g->undo_idx--;
  }

  e = &g->undo[g->undo_len++];
  e->op = UNDO_OP_INSERT;
  e->pos = pos;
  e->old_len = 0;
  e->new_len = n;
  memcpy(e->new_data, bytes, n);
  g->undo_idx = g->undo_len;
}

U0 UndoOnce()
{
  Editor *g = _G();
  UndoEntry *e;

  if (g->undo_idx <= 0) {
    SetStatus("undo: no more actions");
    return;
  }

  e = &g->undo[g->undo_idx - 1];
  if (e->op == UNDO_OP_OVERWRITE) {
    if (e->pos < g->len) {
      SetByteAt(e->pos, e->old_data[0], FALSE);
      g->cur = e->pos;
    }
  } else if (e->op == UNDO_OP_INSERT) {
    if (e->pos >= 0 && e->pos + e->new_len <= g->len) {
      memmove(g->buf + e->pos, g->buf + e->pos + e->new_len, g->len - (e->pos + e->new_len));
      g->len -= e->new_len;
      g->cur = e->pos;
      if (g->cur > g->len) g->cur = g->len;
      g->dirty = TRUE;
    }
  }

  g->undo_idx--;
  g->hex_half = 0;
  KeepVisible();
  SetStatus("undo");
}

U0 RedoOnce()
{
  Editor *g = _G();
  UndoEntry *e;

  if (g->undo_idx >= g->undo_len) {
    SetStatus("redo: no more actions");
    return;
  }

  e = &g->undo[g->undo_idx];
  if (e->op == UNDO_OP_OVERWRITE) {
    if (e->pos < g->len) {
      SetByteAt(e->pos, e->new_data[0], FALSE);
      g->cur = e->pos;
    }
  } else if (e->op == UNDO_OP_INSERT) {
    InsertBytes(e->pos, e->new_data, e->new_len, FALSE);
    g->cur = e->pos + e->new_len;
  }

  g->undo_idx++;
  g->hex_half = 0;
  KeepVisible();
  SetStatus("redo");
}

Bool StartsWith(U8 *s, U8 *prefix)
{
  U64 n = strlen(prefix);
  return strncmp(s, prefix, n) == 0;
}

U0 RecalcBpl()
{
  Editor *g = _G();
  if (!g->bpl_auto) return;

  I64 usable = g->cols - 15;
  I64 bpl = usable / 4;
  if (bpl < 4) bpl = 4;
  if (bpl > 64) bpl = 64;
  g->bpl = bpl;
}

U0 Die(U8 *msg)
{
  write(1,"\x1b[0m\x1b[2J\x1b[H\x1b[?25h",18);
  if (isatty(0)) system("stty sane 2>/dev/null");
  msg;
  "\n";
  exit(1);
}

U0 EnterRaw()
{
  if (isatty(0)) system("stty raw -echo 2>/dev/null");
}

U0 LeaveRaw()
{
  if (isatty(0)) system("stty sane 2>/dev/null");
}

U0 SetStatus(U8 *msg)
{
  Editor *g = _G();
  strcpy(g->status, msg);
}

U0 RefreshSize()
{
  Editor *g = _G();
  WinSize ws;
  ws.row = 24;
  ws.col = 80;
  if (ioctl(1, TIOCGWINSZ, &ws) == -1 || ws.col == 0) {
    g->rows = 24;
    g->cols = 80;
    return;
  }
  g->rows = ws.row;
  g->cols = ws.col;
}

U0 WriteStr(U8 *s)
{
  write(1, s, strlen(s));
}

Bool IsSpace(I64 c)
{
  return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

Bool IsHexChar(I64 c)
{
  if (c >= '0' && c <= '9') return TRUE;
  if (c >= 'a' && c <= 'f') return TRUE;
  if (c >= 'A' && c <= 'F') return TRUE;
  return FALSE;
}

U0 EnsureCap(I64 need)
{
  Editor *g = _G();
  if (need <= g->cap) return;
  I64 ncap = 1024;
  if (g->cap) ncap = g->cap;
  while (ncap < need) ncap *= 2;
  U8 *tmp = realloc(g->buf, ncap)(U8*);
  if (!tmp) Die("out of memory");
  g->buf = tmp;
  g->cap = ncap;
}

U0 AppendByte(U8 b)
{
  Editor *g = _G();
  EnsureCap(g->len + 1);
  g->buf[g->len++] = b;
  g->dirty = TRUE;
}

U0 SetByteAt(I64 idx, U8 b, Bool track_undo)
{
  Editor *g = _G();
  if (idx < g->len) {
    U8 old_b = g->buf[idx];
    g->buf[idx] = b;
    g->dirty = TRUE;
    if (track_undo) PushUndoOverwrite(idx, old_b, b);
    return;
  }
  if (idx == g->len) {
    InsertBytes(idx, &b, 1, track_undo);
  }
}

U0 InsertBytes(I64 pos, U8 *data, I64 n, Bool track_undo)
{
  Editor *g = _G();
  if (n <= 0) return;
  if (pos < 0) pos = 0;
  if (pos > g->len) pos = g->len;

  EnsureCap(g->len + n);
  if (pos < g->len) {
    memmove(g->buf + pos + n, g->buf + pos, g->len - pos);
  }
  memcpy(g->buf + pos, data, n);
  g->len += n;
  g->dirty = TRUE;
  if (track_undo) PushUndoInsert(pos, data, n);
}

I64 HexVal(I64 c)
{
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

U0 EnsureClipCap(I64 need)
{
  Editor *g = _G();
  if (need <= g->clip_cap) return;
  I64 cap = 256;
  if (g->clip_cap) cap = g->clip_cap;
  while (cap < need) cap *= 2;
  U8 *tmp = realloc(g->clip, cap)(U8*);
  if (!tmp) Die("out of memory");
  g->clip = tmp;
  g->clip_cap = cap;
}

I64 PromptLine(U8 *label, U8 *out, I64 cap)
{
  I64 off = 0;
  U8 c;
  I64 n;

  LeaveRaw();
  WriteStr("\x1b[0m\x1b[2K\r");
  WriteStr(label);

  while (off < cap - 1) {
    n = read(0, &c, 1);
    if (n != 1) continue;
    if (c == '\n' || c == '\r') break;
    out[off++] = c;
  }
  out[off] = 0;

  if (c != '\n' && c != '\r') {
    while (TRUE) {
      n = read(0, &c, 1);
      if (n == 1 && (c == '\n' || c == '\r')) break;
      if (n != 1) break;
    }
  }

  EnterRaw();
  return off;
}

I64 ParseSearchPattern(U8 *query, U8 *out, I64 cap)
{
  I64 i = 0;
  I64 olen = 0;
  Bool all_hex = TRUE;

  while (query[i]) {
    if (!IsHexChar(query[i]) && !IsSpace(query[i])) {
      all_hex = FALSE;
      break;
    }
    i++;
  }

  if (!all_hex) {
    i = 0;
    while (query[i] && olen < cap) {
      out[olen++] = query[i++];
    }
    return olen;
  }

  I64 hi = -1;
  i = 0;
  while (query[i]) {
    I64 c = query[i++];
    if (IsSpace(c)) continue;
    I64 v = HexVal(c);
    if (v < 0) return -1;
    if (hi < 0) hi = v;
    else {
      if (olen >= cap) return -1;
      out[olen++] = ((hi << 4) | v);
      hi = -1;
    }
  }

  if (hi >= 0) return -1;
  return olen;
}

I64 FindPattern(U8 *pat, I64 plen, I64 start, Bool forward)
{
  Editor *g = _G();
  I64 i, j;

  if (plen <= 0 || plen > g->len) return -1;

  if (forward) {
    if (start < 0) start = 0;
    for (i = start; i + plen <= g->len; ++i) {
      for (j = 0; j < plen; ++j) {
        if (g->buf[i + j] != pat[j]) goto _next_fwd;
      }
      return i;
_next_fwd:
      ;
    }
    return -1;
  }

  if (start > g->len - plen) start = g->len - plen;
  if (start < 0) return -1;
  for (i = start; i >= 0; --i) {
    for (j = 0; j < plen; ++j) {
      if (g->buf[i + j] != pat[j]) goto _next_rev;
    }
    return i;
_next_rev:
    ;
  }
  return -1;
}

U0 DoSearch(Bool forward)
{
  Editor *g = _G();
  U8 query[256];
  U8 parsed[256];
  U8 *prompt = "search / ";
  if (!forward) prompt = "search ? ";
  I64 qlen = PromptLine(prompt, query, 256);
  I64 plen;
  I64 pos;
  I64 start;

  if (qlen == 0) {
    if (g->search_len <= 0) {
      SetStatus("search: empty pattern");
      return;
    }
    memcpy(parsed, g->search, g->search_len);
    plen = g->search_len;
  } else {
    plen = ParseSearchPattern(query, parsed, 256);
    if (plen <= 0) {
      SetStatus("search: invalid pattern");
      return;
    }
    memcpy(g->search, parsed, plen);
    g->search_len = plen;
  }

  start = g->cur;
  if (forward) start++;
  else start--;
  pos = FindPattern(parsed, plen, start, forward);

  if (pos < 0) {
    SetStatus("search: no match");
    return;
  }

  g->cur = pos;
  g->hex_half = 0;
  KeepVisible();
  snprintf(g->status, 255, "search: match at 0x%lx", pos);
}

U0 CopyMarkedRegion()
{
  Editor *g = _G();
  I64 a, b, n;
  if (!g->mark_on) {
    SetStatus("copy: no mark set");
    return;
  }

  a = g->mark_pos;
  b = g->cur;
  if (a > b) {
    I64 t = a;
    a = b;
    b = t;
  }
  if (b <= a) {
    SetStatus("copy: empty region");
    return;
  }

  n = b - a;
  EnsureClipCap(n);
  memcpy(g->clip, g->buf + a, n);
  g->clip_len = n;
  snprintf(g->status, 255, "copied %ld bytes", n);
}

U0 PasteClipboard()
{
  Editor *g = _G();
  if (g->clip_len <= 0) {
    SetStatus("paste: clipboard empty");
    return;
  }

  InsertBytes(g->cur, g->clip, g->clip_len, TRUE);
  g->cur += g->clip_len;
  g->hex_half = 0;
  snprintf(g->status, 255, "pasted %ld bytes", g->clip_len);
}

U0 GotoOffsetPrompt()
{
  Editor *g = _G();
  U8 query[128];
  U8 *end = NULL;
  I64 base = 10;
  I64 off;

  if (PromptLine("goto offset: ", query, 128) <= 0) {
    SetStatus("goto: cancelled");
    return;
  }

  if (query[0] == '0' && (query[1] == 'x' || query[1] == 'X')) {
    base = 16;
  }

  off = strtoll(query, &end, base);
  if (end == query || *end != 0) {
    SetStatus("goto: invalid number");
    return;
  }
  if (off < 0) off = 0;
  if (off > g->len) off = g->len;

  g->cur = off;
  g->hex_half = 0;
  KeepVisible();
  snprintf(g->status, 255, "goto: 0x%lx", off);
}

U0 MoveCursor(I64 delta)
{
  Editor *g = _G();
  I64 dst = g->cur + delta;
  if (dst < 0) dst = 0;
  if (dst > g->len) dst = g->len;
  g->cur = dst;
  g->hex_half = 0;
}

U0 KeepVisible()
{
  Editor *g = _G();
  I64 bpl = g->bpl;
  I64 vrows = 1;
  if (g->rows > 2) vrows = g->rows - 2;
  I64 first = g->top / bpl;
  I64 last = first + vrows - 1;
  I64 crow = g->cur / bpl;

  if (crow < first) {
    g->top = crow * bpl;
  } else if (crow > last) {
    g->top = (crow - vrows + 1) * bpl;
  }
}

U0 OpenFile(U8 *path)
{
  Editor *g = _G();
  I32 fd = open(path, O_RDONLY);
  if (fd == -1) Die("cannot open file");

  I64 len = lseek(fd, 0, SEEK_END);
  if (len < 0) {
    close(fd);
    Die("lseek failed");
  }
  lseek(fd, 0, SEEK_SET);

  g->path = strdup(path);
  g->cap = 1024;
  if (len > 0) g->cap = len;
  g->buf = malloc(g->cap)(U8*);
  if (!g->buf || !g->path) {
    close(fd);
    Die("out of memory");
  }

  g->len = len;
  I64 off = 0;
  while (off < len) {
    I64 n = read(fd, g->buf + off, len - off);
    if (n <= 0) {
      close(fd);
      Die("read failed");
    }
    off += n;
  }

  close(fd);
}

U0 SaveFile()
{
  Editor *g = _G();
  if (g->readonly) {
    SetStatus("readonly: save disabled");
    return;
  }
  I32 fd = open(g->path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd == -1) {
    SetStatus("save failed: open");
    return;
  }

  I64 off = 0;
  while (off < g->len) {
    I64 n = write(fd, g->buf + off, g->len - off);
    if (n <= 0) {
      close(fd);
      SetStatus("save failed: write");
      return;
    }
    off += n;
  }
  close(fd);
  g->dirty = FALSE;

  snprintf(g->status, 255, "wrote %ld bytes", g->len);
}

I64 ReadKey()
{
  U8 c;
  I64 n;

  while (TRUE) {
    n = read(0, &c, 1);
    if (n == 1) break;
  }

  if (c != 27) return c;

  U8 s0, s1, s2;
  if (read(0, &s0, 1) != 1) return K_ESC;
  if (read(0, &s1, 1) != 1) return K_ESC;

  if (s0 == '[') {
    if (s1 >= '0' && s1 <= '9') {
      if (read(0, &s2, 1) != 1) return K_ESC;
      if (s2 == '~') {
        if (s1 == '1') return K_HOME;
        if (s1 == '4') return K_END;
        if (s1 == '5') return K_PAGE_UP;
        if (s1 == '6') return K_PAGE_DOWN;
        if (s1 == '7') return K_HOME;
        if (s1 == '8') return K_END;
      }
      return K_ESC;
    }
    if (s1 == 'A') return K_ARROW_UP;
    if (s1 == 'B') return K_ARROW_DOWN;
    if (s1 == 'C') return K_ARROW_RIGHT;
    if (s1 == 'D') return K_ARROW_LEFT;
    if (s1 == 'H') return K_HOME;
    if (s1 == 'F') return K_END;
  }

  return K_ESC;
}

U8 PrintCh(U8 b)
{
  if (b >= 32 && b <= 126) return b;
  return '.';
}

U0 DrawLine(I64 off)
{
  Editor *g = _G();
  U8 tmp[256];
  snprintf(tmp, 255, "%08lx  ", off);
  WriteStr(tmp);

  I64 i;
  for (i = 0; i < g->bpl; ++i) {
    I64 idx = off + i;
    if (idx < g->len) {
      Bool sel = (idx == g->cur && g->pane == PANE_HEX);
      if (sel) {
        snprintf(tmp, 255, "\x1b[7m%02x\x1b[0m ", g->buf[idx]);
      } else {
        snprintf(tmp, 255, "%02x ", g->buf[idx]);
      }
      WriteStr(tmp);
    } else {
      WriteStr("   ");
    }
  }

  WriteStr(" |");

  for (i = 0; i < g->bpl; ++i) {
    I64 idx = off + i;
    U8 ch = ' ';
    Bool sel = FALSE;
    if (idx < g->len) {
      ch = PrintCh(g->buf[idx]);
      sel = (idx == g->cur && g->pane == PANE_ASCII);
    }

    if (sel) WriteStr("\x1b[7m");
    write(1, &ch, 1);
    if (sel) WriteStr("\x1b[0m");
  }
  WriteStr("|\x1b[K\r\n");
}

U0 DrawScreen()
{
  Editor *g = _G();
  U8 tmp[512];
  U8 *pane_name;
  U8 *dirty_text;
  U8 *mark_text;
  U8 *ro_text;
  RefreshSize();
  RecalcBpl();

  WriteStr("\x1b[?25l\x1b[H");

  pane_name = "HEX";
  if (g->pane == PANE_ASCII) pane_name = "ASCII";
  mark_text = "off";
  if (g->mark_on) mark_text = "on";
  ro_text = "";
  if (g->readonly) ro_text = "[RO]";
  dirty_text = "";
  if (g->dirty) dirty_text = "[modified]";

  snprintf(tmp, 511,
    "\x1b[1m%s\x1b[0m  len=%ld  cur=0x%lx  bpl=%ld  pane=%s  mark=%s  %s %s\r\n",
    g->path,
    g->len,
    g->cur,
    g->bpl,
    pane_name,
    mark_text,
    ro_text,
    dirty_text);
  WriteStr(tmp);

  I64 vrows = 1;
  if (g->rows > 2) vrows = g->rows - 2;
  I64 r;
  for (r = 0; r < vrows; ++r) {
    I64 off = g->top + r * g->bpl;
    I64 crow_base = (g->cur / g->bpl) * g->bpl;
    if (off < g->len || off == crow_base) {
      DrawLine(off);
    } else {
      WriteStr("~\x1b[K\r\n");
    }
  }

  WriteStr("\x1b[7m");
  if (strlen(g->status) > 0) {
    WriteStr(g->status);
  } else {
    WriteStr("Ctrl+S save | Ctrl+X save+quit | Ctrl+C quit | / search | v/y/p mark-copy-paste");
  }
  WriteStr("\x1b[0m\x1b[K");
}

U0 ProcessKey(I64 k, Bool *running)
{
  Editor *g = _G();
  I64 bpl = g->bpl;
  I64 page_rows = 1;
  if (g->rows > 2) page_rows = (g->rows - 2);
  I64 page = page_rows * bpl;

  if (k == 24) {
    SaveFile();
    if (!g->dirty) {
      *running = FALSE;
    }
    return;
  }

  if (k == 3) {
    if (g->dirty && !g->quit_confirm) {
      g->quit_confirm = TRUE;
      SetStatus("unsaved changes: press Ctrl+C again to quit");
      return;
    }
    *running = FALSE;
    return;
  }

  if (k == 17) {
    if (g->dirty && !g->quit_confirm) {
      g->quit_confirm = TRUE;
      SetStatus("unsaved changes: press Ctrl+Q again to quit");
      return;
    }
    *running = FALSE;
    return;
  }

  if (k == 19) {
    SaveFile();
    g->quit_confirm = FALSE;
    return;
  }

  if (k == '\t') {
    if (g->pane == PANE_HEX) g->pane = PANE_ASCII;
    else g->pane = PANE_HEX;
    g->hex_half = 0;
    g->quit_confirm = FALSE;
    if (g->pane == PANE_HEX) SetStatus("pane: HEX");
    else SetStatus("pane: ASCII");
    return;
  }

  if (k == '/') {
    DoSearch(TRUE);
    return;
  }

  if (k == 18) {
    DoSearch(FALSE);
    return;
  }

  if (k == 'v' || k == 0) {
    if (!g->mark_on) {
      g->mark_on = TRUE;
      g->mark_pos = g->cur;
      snprintf(g->status, 255, "mark set at 0x%lx", g->mark_pos);
    } else {
      g->mark_on = FALSE;
      SetStatus("mark cleared");
    }
    return;
  }

  if (k == 'y' || k == 4) {
    CopyMarkedRegion();
    return;
  }

  if (k == 'p') {
    if (g->readonly) {
      SetStatus("readonly: cannot paste");
      return;
    }
    PasteClipboard();
    KeepVisible();
    return;
  }

  if (k == 'g' || k == 7) {
    GotoOffsetPrompt();
    return;
  }

  if (k == 'u' || k == 26) {
    if (g->readonly) {
      SetStatus("readonly: cannot undo");
      return;
    }
    UndoOnce();
    return;
  }

  if (k == 'U' || k == 25) {
    if (g->readonly) {
      SetStatus("readonly: cannot redo");
      return;
    }
    RedoOnce();
    return;
  }

  if (k == K_ARROW_LEFT || k == 'h') MoveCursor(-1);
  else if (k == K_ARROW_RIGHT || k == 'l') MoveCursor(1);
  else if (k == K_ARROW_UP || k == 'k') MoveCursor(-bpl);
  else if (k == K_ARROW_DOWN || k == 'j') MoveCursor(bpl);
  else if (k == K_PAGE_UP) MoveCursor(-page);
  else if (k == K_PAGE_DOWN) MoveCursor(page);
  else if (k == K_HOME) { g->cur = 0; g->hex_half = 0; }
  else if (k == K_END) { g->cur = g->len; g->hex_half = 0; }
  else {
    if (g->pane == PANE_HEX) {
      I64 v = HexVal(k);
      if (v >= 0) {
        if (g->readonly) {
          SetStatus("readonly: cannot edit");
          return;
        }
        if (g->cur == g->len) AppendByte(0);
        U8 b = g->buf[g->cur];
        if (!g->hex_half) {
          b = ((v << 4) | (b & 15));
          SetByteAt(g->cur, b, TRUE);
          g->hex_half = 1;
        } else {
          b = ((b & 0xF0) | v);
          SetByteAt(g->cur, b, TRUE);
          g->hex_half = 0;
          MoveCursor(1);
        }
      }
    } else {
      if (k >= 32 && k <= 126) {
        if (g->readonly) {
          SetStatus("readonly: cannot edit");
          return;
        }
        SetByteAt(g->cur, k, TRUE);
        MoveCursor(1);
      }
    }
  }

  g->quit_confirm = FALSE;
  KeepVisible();
}

U0 InitEditor(U8 *path)
{
  Editor *g = _G();
  memset(g, 0, sizeof(Editor));
  OpenFile(path);
  g->pane = PANE_HEX;
  g->bpl = 16;
  g->bpl_auto = TRUE;
  g->readonly = FALSE;
  g->top = 0;
  g->cur = 0;
  g->hex_half = 0;
  g->dirty = FALSE;
  g->quit_confirm = FALSE;
  SetStatus("Ctrl+S save | Ctrl+X save+quit | Ctrl+C quit | / search | v/y/p mark-copy-paste");
}

I32 Main(I32 argc, U8 **argv)
{
  Editor *g = _G();
  U8 *file = NULL;
  I64 req_bpl = 16;
  Bool req_auto = TRUE;
  Bool req_readonly = FALSE;
  I32 i = 1;

  while (i < argc) {
    U8 *arg = argv[i];
    if (!strcmp(arg, "-h") || !strcmp(arg, "--help")) {
      "usage: %s [options] <file>\n", argv[0];
      "  -r, --readonly       open read-only\n";
      "  -s, --sector         set line length to 32\n";
      "  -m, --maximize       auto line length from terminal width\n";
      "  -lN, --linelength N  set line length\n";
      return 0;
    } else if (!strcmp(arg, "-r") || !strcmp(arg, "--readonly")) {
      req_readonly = TRUE;
    } else if (!strcmp(arg, "-s") || !strcmp(arg, "--sector")) {
      req_bpl = 32;
      req_auto = FALSE;
    } else if (!strcmp(arg, "-m") || !strcmp(arg, "--maximize")) {
      req_auto = TRUE;
    } else if (!strcmp(arg, "--color")) {
      /* ANSI color is currently always enabled; accept for CLI compatibility. */
    } else if (StartsWith(arg, "-l") && strlen(arg) > 2) {
      U8 *end = NULL;
      I64 n = strtoll(arg + 2, &end, 10);
      if (end == arg + 2 || *end != 0 || n < 4 || n > 64) {
        "invalid line length\n";
        return 1;
      }
      req_bpl = n;
      req_auto = FALSE;
    } else if (!strcmp(arg, "--linelength")) {
      U8 *end = NULL;
      I64 n;
      i++;
      if (i >= argc) {
        "missing value for --linelength\n";
        return 1;
      }
      n = strtoll(argv[i], &end, 10);
      if (end == argv[i] || *end != 0 || n < 4 || n > 64) {
        "invalid line length\n";
        return 1;
      }
      req_bpl = n;
      req_auto = FALSE;
    } else if (arg[0] == '-') {
      "unknown option: %s\n", arg;
      return 1;
    } else {
      file = arg;
      break;
    }
    i++;
  }

  if (!file || i + 1 != argc) {
    "usage: %s [options] <file>\n", argv[0];
    return 1;
  }

  InitEditor(file);
  g->bpl = req_bpl;
  g->bpl_auto = req_auto;
  g->readonly = req_readonly;

  WriteStr("\x1b[2J\x1b[H");
  EnterRaw();

  Bool running = TRUE;
  while (running) {
    KeepVisible();
    DrawScreen();
    I64 k = ReadKey();
    ProcessKey(k, &running);
  }

  LeaveRaw();
  WriteStr("\x1b[0m\x1b[2J\x1b[H\x1b[?25h");

  /* Keep process-exit cleanup minimal; allocator interop can vary across hcc/libc builds. */
  return 0;
}
