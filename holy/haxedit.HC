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
#define K_MOUSE       1008
#define K_INSERT      1009
#define K_DELETE      1010
#define K_F1          1011
#define K_F2          1012
#define K_F3          1013
#define K_F4          1014
#define K_F5          1015
#define K_F6          1016
#define K_F7          1017
#define K_F8          1018
#define K_F9          1019
#define K_F10         1020
#define K_F11         1021
#define K_F12         1022
#define K_CTRL_SHIFT_C 1023
#define K_ALT_ARROW_LEFT 1024
#define K_ALT_ARROW_RIGHT 1025
#define K_ALT_ARROW_UP 1026
#define K_ALT_ARROW_DOWN 1027
#define K_ALT_BASE    2000

#define PANE_HEX   0
#define PANE_ASCII 1

#define TIOCGWINSZ 0x5413
#define UNDO_MAX 256
#define UNDO_DATA_MAX 4096
#define SIGTSTP 20

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
extern "c" I32 kill(I32 pid, I32 sig);
extern "c" I32 getpid(U0);

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
  I64 mark_pane;
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
  I64 mouse_kind;
  I64 mouse_row;
  I64 mouse_col;
  Bool mouse_down;
  I64 mouse_start_pos;
  I64 mouse_start_pane;
  U8 status[256];
};

Editor *_G(U0)
{
  static Editor g_state;
  return &g_state;
}

U0 KeepVisible();
U0 SetStatus(U8 *msg);
U0 WriteStr(U8 *s);
U0 InitEditor(U8 *path);
U0 ShowHelp();
I64 ReadKey();
U0 YankToFilePrompt();
U0 FillMarkedRegionPrompt();
U0 TruncateFilePrompt();
U0 CopyMarkedRegionToSystemClipboard();
U0 DeleteBackwardBytes(I64 n);
U0 SuspendEditor();
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
  WriteStr("\x1b[?1000h\x1b[?1002h\x1b[?1006h");
}

U0 LeaveRaw()
{
  WriteStr("\x1b[?1000l\x1b[?1002l\x1b[?1006l");
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

U0 OpenFilePrompt()
{
  Editor *g = _G();
  U8 path[512];
  I32 fd;
  Bool keep_readonly;
  I64 keep_bpl;
  Bool keep_bpl_auto;

  if (PromptLine("file name: ", path, 512) <= 0) {
    SetStatus("open: cancelled");
    return;
  }

  fd = open(path, O_RDONLY);
  if (fd < 0) {
    SetStatus("open: cannot open file");
    return;
  }
  close(fd);

  keep_readonly = g->readonly;
  keep_bpl = g->bpl;
  keep_bpl_auto = g->bpl_auto;
  InitEditor(path);
  g->readonly = keep_readonly;
  g->bpl = keep_bpl;
  g->bpl_auto = keep_bpl_auto;
  KeepVisible();
  SetStatus("opened file");
}

U0 ShowHelp()
{
  WriteStr("\x1b[2J\x1b[H");
  WriteStr("HaxEdit Help\r\n");
  WriteStr("\r\n");
  WriteStr("Movement: Arrows, h/j/k/l, PgUp/PgDn, Home/End\r\n");
  WriteStr("Edit: type in hex/ascii pane, Ctrl+Q quoted insert\r\n");
  WriteStr("Search: / or Ctrl+S forward, Ctrl+R backward\r\n");
  WriteStr("Mark/Copy/Paste: v set mark, y copy, Ctrl+Y paste\r\n");
  WriteStr("File: Ctrl+O open, Ctrl+W save, Ctrl+X save+quit, Ctrl+C quit\r\n");
  WriteStr("Pane: Tab or Ctrl+T toggle hex/ascii\r\n");
  WriteStr("Undo/Redo: u or Ctrl+U/Ctrl+Z/Ctrl+_ undo, U redo\r\n");
  WriteStr("Function keys: F2 save, F3 open, F4 goto, F5/F6 page, F7/F8 copy/paste, F9 mark, F10 save+quit\r\n");
  WriteStr("\r\nPress any key to return...");
  ReadKey();
  SetStatus("help");
}

U0 YankToFilePrompt()
{
  Editor *g = _G();
  U8 path[512];
  U8 yn[16];
  I32 fd;
  I64 off;
  I64 n;

  if (g->clip_len <= 0) {
    SetStatus("paste-to-file: clipboard empty");
    return;
  }

  if (PromptLine("file name: ", path, 512) <= 0) {
    SetStatus("paste-to-file: cancelled");
    return;
  }

  fd = open(path, O_RDONLY);
  if (fd >= 0) {
    close(fd);
    if (PromptLine("overwrite file? (y/N): ", yn, 16) <= 0) {
      SetStatus("paste-to-file: cancelled");
      return;
    }
    if (!(yn[0] == 'y' || yn[0] == 'Y')) {
      SetStatus("paste-to-file: cancelled");
      return;
    }
  }

  fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd < 0) {
    SetStatus("paste-to-file: open failed");
    return;
  }

  off = 0;
  while (off < g->clip_len) {
    n = write(fd, g->clip + off, g->clip_len - off);
    if (n <= 0) {
      close(fd);
      SetStatus("paste-to-file: write failed");
      return;
    }
    off += n;
  }
  close(fd);
  snprintf(g->status, 255, "paste-to-file: wrote %ld bytes", g->clip_len);
}

U0 FillMarkedRegionPrompt()
{
  Editor *g = _G();
  U8 input[256];
  U8 pat[256];
  U8 *label;
  I64 ilen;
  I64 plen = 0;
  I64 a, b, n, i;

  if (!g->mark_on) {
    SetStatus("fill: no mark set");
    return;
  }
  if (g->readonly) {
    SetStatus("readonly: cannot fill");
    return;
  }

  label = "ascii fill: ";
  if (g->pane == PANE_HEX) label = "hex fill: ";
  if (PromptLine(label, input, 256) <= 0) {
    SetStatus("fill: cancelled");
    return;
  }

  if (g->pane == PANE_HEX) {
    ilen = strlen(input);
    if (ilen == 1) {
      I64 hv = HexVal(input[0]);
      if (hv < 0) {
        SetStatus("fill: invalid hex string");
        return;
      }
      pat[0] = hv;
      plen = 1;
    } else {
      plen = ParseSearchPattern(input, pat, 256);
      if (plen <= 0) {
        SetStatus("fill: invalid hex string");
        return;
      }
    }
  } else {
    plen = strlen(input);
    if (plen <= 0) {
      SetStatus("fill: empty pattern");
      return;
    }
    if (plen > 256) plen = 256;
    memcpy(pat, input, plen);
  }

  a = g->mark_pos;
  b = g->cur;
  if (a > b) {
    I64 t = a;
    a = b;
    b = t;
  }
  if (b <= a) {
    SetStatus("fill: empty region");
    return;
  }

  n = b - a;
  for (i = 0; i < n; ++i) {
    g->buf[a + i] = pat[i % plen];
  }
  g->dirty = TRUE;
  snprintf(g->status, 255, "fill: wrote %ld bytes", n);
}

U0 TruncateFilePrompt()
{
  Editor *g = _G();
  U8 query[128];
  U8 *end = NULL;
  I64 base = 10;
  I64 off;

  if (g->readonly) {
    SetStatus("readonly: cannot truncate");
    return;
  }

  if (PromptLine("truncate at offset: ", query, 128) <= 0) {
    SetStatus("truncate: cancelled");
    return;
  }

  if (query[0] == '0' && (query[1] == 'x' || query[1] == 'X')) {
    base = 16;
  }
  off = strtoll(query, &end, base);
  if (end == query || *end != 0) {
    SetStatus("truncate: invalid number");
    return;
  }
  if (off < 0) off = 0;
  if (off > g->len) off = g->len;

  g->len = off;
  if (g->cur > g->len) g->cur = g->len;
  g->hex_half = 0;
  if (g->mark_on && (g->mark_pos >= g->len || g->cur >= g->len)) {
    g->mark_on = FALSE;
  }
  g->dirty = TRUE;
  KeepVisible();
  snprintf(g->status, 255, "truncate: new size 0x%lx", g->len);
}

U8 *Base64Encode(U8 *src, I64 n, I64 *out_len)
{
  U8 *tbl = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  I64 enc_len;
  I64 i = 0, j = 0;
  U8 *out;

  if (n < 0) n = 0;
  enc_len = ((n + 2) / 3) * 4;
  out = malloc(enc_len + 1)(U8*);
  if (!out) return NULL;

  while (i < n) {
    I64 a = src[i++] & 0xFF;
    I64 b = -1;
    I64 c = -1;
    I64 triple;
    if (i < n) b = src[i++] & 0xFF;
    if (i < n) c = src[i++] & 0xFF;

    triple = (a << 16);
    if (b >= 0) triple |= (b << 8);
    if (c >= 0) triple |= c;

    out[j++] = tbl[(triple >> 18) & 63];
    out[j++] = tbl[(triple >> 12) & 63];
    if (b >= 0) out[j++] = tbl[(triple >> 6) & 63];
    else out[j++] = '=';
    if (c >= 0) out[j++] = tbl[triple & 63];
    else out[j++] = '=';
  }

  out[j] = 0;
  if (out_len) *out_len = j;
  return out;
}

Bool SetSystemClipboardBytes(U8 *data, I64 n)
{
  U8 *enc;
  I64 enc_len = 0;

  if (!data || n <= 0) return FALSE;

  enc = Base64Encode(data, n, &enc_len);
  if (!enc) return FALSE;

  WriteStr("\x1b]52;c;");
  write(1, enc, enc_len);
  WriteStr("\x07");
  free(enc);
  return TRUE;
}

U0 CopyMarkedRegionToSystemClipboard()
{
  Editor *g = _G();
  I64 a, b, n, i, pos;
  U8 *tmp;
  U8 hx[3];

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
  if (g->pane == PANE_HEX) {
    tmp = malloc(n * 3)(U8*);
    if (!tmp) {
      SetStatus("copy: out of memory");
      return;
    }
    pos = 0;
    for (i = 0; i < n; ++i) {
      snprintf(hx, 3, "%02x", g->buf[a + i] & 0xFF);
      tmp[pos++] = hx[0];
      tmp[pos++] = hx[1];
      if (i + 1 < n) tmp[pos++] = ' ';
    }
    if (!SetSystemClipboardBytes(tmp, pos)) {
      free(tmp);
      SetStatus("copy: system clipboard failed");
      return;
    }
    free(tmp);
  } else {
    if (!SetSystemClipboardBytes(g->buf + a, n)) {
      SetStatus("copy: system clipboard failed");
      return;
    }
  }

  SetStatus("copied to system clipboard");
}

U0 DeleteBackwardBytes(I64 n)
{
  Editor *g = _G();
  I64 start;
  I64 del;

  if (g->readonly) {
    SetStatus("readonly: cannot delete");
    return;
  }
  if (n <= 0) return;
  if (g->cur <= 0) return;

  start = g->cur - n;
  if (start < 0) start = 0;
  del = g->cur - start;
  if (del <= 0) return;

  if (g->cur < g->len) {
    memmove(g->buf + start, g->buf + g->cur, g->len - g->cur);
  }
  g->len -= del;
  g->cur = start;
  g->hex_half = 0;
  g->dirty = TRUE;

  if (g->mark_on && (g->mark_pos > g->len || g->cur > g->len)) {
    g->mark_on = FALSE;
  }

  KeepVisible();
  snprintf(g->status, 255, "deleted %ld bytes", del);
}

U0 SuspendEditor()
{
  LeaveRaw();
  WriteStr("\x1b[?25h\x1b[0m");
  kill(getpid(), SIGTSTP);
  EnterRaw();
  RefreshSize();
  SetStatus("resumed");
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
  Editor *g = _G();
  U8 c;
  I64 n;

  while (TRUE) {
    n = read(0, &c, 1);
    if (n == 1) break;
  }

  if (c != 27) return c;

  U8 s0, s1;
  if (read(0, &s0, 1) != 1) return K_ESC;
  if (s0 != '[' && s0 != 'O') {
    if (s0 == 27) {
      U8 t0, t1;
      if (read(0, &t0, 1) == 1 && t0 == '[' && read(0, &t1, 1) == 1) {
        if (t1 == 'A') return K_ALT_ARROW_UP;
        if (t1 == 'B') return K_ALT_ARROW_DOWN;
        if (t1 == 'C') return K_ALT_ARROW_RIGHT;
        if (t1 == 'D') return K_ALT_ARROW_LEFT;
      }
      return K_ESC;
    }
    return K_ALT_BASE + s0;
  }
  if (read(0, &s1, 1) != 1) return K_ESC;

  if (s0 == '[') {
    if (s1 == '<') {
      I64 b = 0, x = 0, y = 0;
      U8 ch;
      while (TRUE) {
        if (read(0, &ch, 1) != 1) return K_ESC;
        if (ch == ';') break;
        if (ch < '0' || ch > '9') return K_ESC;
        b = b * 10 + (ch - '0');
      }
      while (TRUE) {
        if (read(0, &ch, 1) != 1) return K_ESC;
        if (ch == ';') break;
        if (ch < '0' || ch > '9') return K_ESC;
        x = x * 10 + (ch - '0');
      }
      while (TRUE) {
        if (read(0, &ch, 1) != 1) return K_ESC;
        if (ch == 'M' || ch == 'm') break;
        if (ch < '0' || ch > '9') return K_ESC;
        y = y * 10 + (ch - '0');
      }

      g->mouse_col = 0;
      if (x > 0) g->mouse_col = x - 1;
      g->mouse_row = 0;
      if (y > 0) g->mouse_row = y - 1;

      /* SGR mouse: release may be '<...m' OR button=3 with 'M' on some terminals. */
      if (ch == 'm' || ((b & 3) == 3)) {
        g->mouse_kind = 2;                /* release */
      } else if ((b & 32) && ((b & 3) == 0)) {
        g->mouse_kind = 1;                /* left-button drag */
      } else if ((b & 3) == 0) {
        g->mouse_kind = 0;                /* left-button press */
      } else {
        g->mouse_kind = -1;               /* ignore non-left events */
      }
      return K_MOUSE;
    }

    if (s1 >= '0' && s1 <= '9') {
      I64 params[4];
      I64 pcount = 1;
      U8 ch;
      params[0] = s1 - '0';
      while (TRUE) {
        if (read(0, &ch, 1) != 1) return K_ESC;
        if (ch >= '0' && ch <= '9') {
          params[pcount - 1] = params[pcount - 1] * 10 + (ch - '0');
          continue;
        }
        if (ch == ';') {
          if (pcount < 4) params[pcount++] = 0;
          continue;
        }
        if (ch == 'u') {
          if (pcount >= 2) {
            I64 code_u = params[0];
            I64 mod_u = params[1];
            if (mod_u == 6 && (code_u == 67 || code_u == 99)) return K_CTRL_SHIFT_C;
          }
          return K_ESC;
        }
        if (ch == '~') {
          I64 code = params[0];
          if (code == 27 && pcount >= 3) {
            if (params[1] == 6 && (params[2] == 67 || params[2] == 99)) return K_CTRL_SHIFT_C;
          }
          if (code == 1 || code == 7) return K_HOME;
          if (code == 2) return K_INSERT;
          if (code == 3) return K_DELETE;
          if (code == 4 || code == 8) return K_END;
          if (code == 5) return K_PAGE_UP;
          if (code == 6) return K_PAGE_DOWN;
          if (code == 11) return K_F1;
          if (code == 12) return K_F2;
          if (code == 13) return K_F3;
          if (code == 14) return K_F4;
          if (code == 15) return K_F5;
          if (code == 17) return K_F6;
          if (code == 18) return K_F7;
          if (code == 19) return K_F8;
          if (code == 20) return K_F9;
          if (code == 21) return K_F10;
          if (code == 23) return K_F11;
          if (code == 24) return K_F12;
          return K_ESC;
        }
        return K_ESC;
      }
    }
    if (s1 == 'A') return K_ARROW_UP;
    if (s1 == 'B') return K_ARROW_DOWN;
    if (s1 == 'C') return K_ARROW_RIGHT;
    if (s1 == 'D') return K_ARROW_LEFT;
    if (s1 == 'H') return K_HOME;
    if (s1 == 'F') return K_END;
  }

  if (s0 == 'O') {
    if (s1 == 'P') return K_F1;
    if (s1 == 'Q') return K_F2;
    if (s1 == 'R') return K_F3;
    if (s1 == 'S') return K_F4;
  }

  return K_ESC;
}

U8 PrintCh(U8 b)
{
  if (b >= 32 && b <= 126) return b;
  return '.';
}

U8 *BaseName(U8 *path)
{
  I64 i = 0;
  I64 last = 0;
  if (!path) return "";
  while (path[i]) {
    if (path[i] == '/') last = i + 1;
    i++;
  }
  return path + last;
}

U0 DrawLine(I64 off)
{
  Editor *g = _G();
  U8 tmp[256];
  I64 sel_min = 0;
  I64 sel_max = -1;
  Bool have_sel = FALSE;
  I64 sel_pane = g->pane;

  if (g->mark_on) {
    sel_min = g->mark_pos;
    sel_max = g->cur;
    sel_pane = g->mark_pane;
    if (sel_min > sel_max) {
      I64 t = sel_min;
      sel_min = sel_max;
      sel_max = t;
    }
    if (sel_max > sel_min) {
      have_sel = TRUE;
    }
  }

  snprintf(tmp, 255, "%08lx  ", off);
  WriteStr(tmp);

  I64 i;
  for (i = 0; i < g->bpl; ++i) {
    I64 idx = off + i;
    if (idx < g->len) {
      Bool marked = FALSE;
      Bool active_sel = (idx == g->cur && g->pane == PANE_HEX);
      Bool ghost_sel = (idx == g->cur && g->pane == PANE_ASCII);
      if (have_sel && idx >= sel_min && idx < sel_max) marked = TRUE;
      Bool active_mark = marked && sel_pane == PANE_HEX;
      Bool ghost_mark = marked && sel_pane == PANE_ASCII;
      I64 hv = g->buf[idx] & 0xFF;
      if (active_sel) {
        snprintf(tmp, 255, "\x1b[7m%02x\x1b[0m ", hv);
      } else if (active_mark) {
        snprintf(tmp, 255, "\x1b[7m%02x\x1b[0m ", hv);
      } else if (ghost_sel || ghost_mark) {
        snprintf(tmp, 255, "\x1b[2m%02x\x1b[0m ", hv);
      } else {
        snprintf(tmp, 255, "%02x ", hv);
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
    Bool marked = FALSE;
    Bool active_sel = FALSE;
    Bool ghost_sel = FALSE;
    if (idx < g->len) {
      ch = PrintCh(g->buf[idx]);
      active_sel = (idx == g->cur && g->pane == PANE_ASCII);
      ghost_sel = (idx == g->cur && g->pane == PANE_HEX);
      if (have_sel && idx >= sel_min && idx < sel_max) marked = TRUE;
    }
    Bool active_mark = marked && sel_pane == PANE_ASCII;
    Bool ghost_mark = marked && sel_pane == PANE_HEX;

    if (active_sel) WriteStr("\x1b[7m");
    else if (active_mark) WriteStr("\x1b[7m");
    else if (ghost_sel || ghost_mark) WriteStr("\x1b[2m");
    write(1, &ch, 1);
    if (active_sel || active_mark || ghost_sel || ghost_mark) WriteStr("\x1b[0m");
  }
  WriteStr("|\x1b[K\r\n");
}

U0 DrawScreen()
{
  Editor *g = _G();
  U8 tmp[512];
  U8 status_line[512];
  U8 name_field[64];
  U8 *name;
  I64 pct;
  I64 cur_disp;
  I64 end_disp;
  I64 used;
  I64 pad_right;
  RefreshSize();
  RecalcBpl();

  WriteStr("\x1b[?25l\x1b[H");

  pct = 0;
  if (g->len <= 1) {
    if (g->len == 1 && g->cur > 0) pct = 100;
  } else {
    pct = (g->cur * 100) / (g->len - 1);
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
  }

  I64 vrows = 1;
  if (g->rows > 1) vrows = g->rows - 1;
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

  name = BaseName(g->path);
  cur_disp = g->cur;
  end_disp = g->len;
  snprintf(name_field, 63, "%-16s", name);
  snprintf(status_line, 511, "---  %s --0x%lX/0x%lX--%ld%%", name_field, cur_disp, end_disp, pct);
  used = strlen(status_line);
  if (used > g->cols) used = g->cols;
  pad_right = g->cols - used;
  if (pad_right < 0) pad_right = 0;

  write(1, status_line, used);
  for (r = 0; r < pad_right; ++r) write(1, "-", 1);
  WriteStr("\x1b[0m");
}

U0 ProcessKey(I64 k, Bool *running)
{
  Editor *g = _G();
  I64 bpl = g->bpl;
  I64 page_rows = 1;
  if (g->rows > 2) page_rows = (g->rows - 2);
  I64 page = page_rows * bpl;

  if (k == K_MOUSE) {
    if (g->mouse_kind < 0) return;

    I64 row = g->mouse_row;
    I64 col = g->mouse_col;
    I64 hex_start = 10;
    I64 ascii_start = hex_start + 3 * g->bpl + 2;
    I64 idx = -1;
    I64 pane = g->pane;
    I64 line_idx, off, loc;

    if (row < 0 || row >= g->rows - 1) return;

    if (col >= hex_start && col < hex_start + 3 * g->bpl) {
      idx = (col - hex_start) / 3;
      pane = PANE_HEX;
    } else if (col >= ascii_start && col < ascii_start + g->bpl) {
      idx = col - ascii_start;
      pane = PANE_ASCII;
    } else {
      return;
    }

    line_idx = row;
    off = g->top + line_idx * g->bpl;
    loc = off + idx;
    if (loc < 0) loc = 0;
    if (loc > g->len) loc = g->len;

    g->pane = pane;
    g->cur = loc;
    g->hex_half = 0;
    KeepVisible();

    if (g->mouse_kind == 0) {
      /* Press: arm drag selection, but do not create one yet. */
      g->mouse_down = TRUE;
      g->mouse_start_pos = loc;
      g->mouse_start_pane = pane;
      g->mark_on = FALSE;
    } else if (g->mouse_kind == 1) {
      if (!g->mouse_down) return;
      /* Drag: create/extend selection from press point. */
      if (!g->mark_on) {
        g->mark_on = TRUE;
        g->mark_pane = g->mouse_start_pane;
        g->mark_pos = g->mouse_start_pos;
      }
    } else if (g->mouse_kind == 2) {
      /* Release: stop extending selection. */
      g->mouse_down = FALSE;
      if (g->mark_on && g->cur == g->mark_pos) {
        /* Click without drag should leave no selection highlight. */
        g->mark_on = FALSE;
      }
    }
    return;
  }

  if (k == 24) {
    SaveFile();
    if (!g->dirty) {
      *running = FALSE;
    }
    return;
  }

  if (k == 127 || k == 8) {
    DeleteBackwardBytes(1);
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
    I64 qk;
    if (g->readonly) {
      SetStatus("readonly: cannot edit");
      return;
    }
    qk = ReadKey();
    if (qk >= 0 && qk <= 255) {
      U8 b = qk & 0xFF;
      SetByteAt(g->cur, b, TRUE);
      MoveCursor(1);
      KeepVisible();
      SetStatus("quoted insert");
    }
    return;
  }

  if (k == 23) {
    SaveFile();
    g->quit_confirm = FALSE;
    return;
  }

  if (k == K_F2) {
    SaveFile();
    g->quit_confirm = FALSE;
    return;
  }

  if (k == K_F1) {
    ShowHelp();
    return;
  }

  if (k == K_F3) {
    OpenFilePrompt();
    return;
  }

  if (k == K_F4) {
    GotoOffsetPrompt();
    return;
  }

  if (k == K_F5) { MoveCursor(-page); KeepVisible(); return; }
  if (k == K_F6) { MoveCursor(page); KeepVisible(); return; }
  if (k == K_F7) { CopyMarkedRegion(); return; }
  if (k == K_F8) {
    if (g->readonly) {
      SetStatus("readonly: cannot paste");
      return;
    }
    PasteClipboard();
    KeepVisible();
    return;
  }
  if (k == K_F9) {
    if (!g->mark_on) {
      g->mark_on = TRUE;
      g->mark_pane = g->pane;
      g->mark_pos = g->cur;
      snprintf(g->status, 255, "mark set at 0x%lx", g->mark_pos);
    } else {
      g->mark_on = FALSE;
      SetStatus("mark cleared");
    }
    return;
  }
  if (k == K_F10) {
    SaveFile();
    if (!g->dirty) *running = FALSE;
    return;
  }
  if (k == K_F11) {
    YankToFilePrompt();
    return;
  }
  if (k == K_F12) {
    FillMarkedRegionPrompt();
    return;
  }

  if (k == '\t' || k == 20) {
    if (g->pane == PANE_HEX) g->pane = PANE_ASCII;
    else g->pane = PANE_HEX;
    g->hex_half = 0;
    g->quit_confirm = FALSE;
    if (g->pane == PANE_HEX) SetStatus("pane: HEX");
    else SetStatus("pane: ASCII");
    return;
  }

  if (k == 15) {
    OpenFilePrompt();
    return;
  }

  if (k == 12) {
    SetStatus("redisplay");
    return;
  }

  if (k == K_ALT_BASE + 'o' || k == K_ALT_BASE + 'O') {
    OpenFilePrompt();
    return;
  }

  if (k == '/') {
    DoSearch(TRUE);
    return;
  }

  if (k == 19) {
    DoSearch(TRUE);
    return;
  }

  if (k == 18) {
    DoSearch(FALSE);
    return;
  }

  if (k == K_ALT_BASE + 'v' || k == K_ALT_BASE + 'V') {
    MoveCursor(-page);
    KeepVisible();
    return;
  }

  if (k == K_ALT_BASE + '<') {
    g->cur = 0;
    g->hex_half = 0;
    KeepVisible();
    return;
  }

  if (k == K_ALT_BASE + '>') {
    g->cur = g->len;
    g->hex_half = 0;
    KeepVisible();
    return;
  }

  if (k == K_ALT_BASE + 'l' || k == K_ALT_BASE + 'L') {
    g->top = (g->cur / bpl) * bpl;
    KeepVisible();
    SetStatus("recenter");
    return;
  }

  if (k == K_ALT_BASE + 'h' || k == K_ALT_BASE + 'H') {
    ShowHelp();
    return;
  }

  if (k == 'v' || k == 0) {
    if (!g->mark_on) {
      g->mark_on = TRUE;
      g->mark_pane = g->pane;
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

  if (k == K_CTRL_SHIFT_C) {
    CopyMarkedRegionToSystemClipboard();
    return;
  }

  if (k == K_ALT_BASE + 'w' || k == K_ALT_BASE + 'W') {
    CopyMarkedRegion();
    return;
  }

  if (k == K_DELETE) {
    CopyMarkedRegion();
    return;
  }

  if (k == 'p' || k == 25) {
    if (g->readonly) {
      SetStatus("readonly: cannot paste");
      return;
    }
    PasteClipboard();
    KeepVisible();
    return;
  }

  if (k == K_ALT_BASE + 'y' || k == K_ALT_BASE + 'Y') {
    YankToFilePrompt();
    return;
  }

  if (k == K_INSERT) {
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

  if (k == K_ALT_BASE + 'i' || k == K_ALT_BASE + 'I') {
    FillMarkedRegionPrompt();
    return;
  }

  if (k == K_ALT_BASE + 'q' || k == K_ALT_BASE + 'Q') {
    I64 qk;
    if (g->readonly) {
      SetStatus("readonly: cannot edit");
      return;
    }
    qk = ReadKey();
    if (qk >= 0 && qk <= 255) {
      U8 b = qk & 0xFF;
      SetByteAt(g->cur, b, TRUE);
      MoveCursor(1);
      KeepVisible();
      SetStatus("quoted insert");
    }
    return;
  }

  if (k == K_ALT_BASE + 8) {
    DeleteBackwardBytes(4);
    return;
  }

  if (k == K_ALT_BASE + 't' || k == K_ALT_BASE + 'T') {
    TruncateFilePrompt();
    return;
  }

  if (k == 'u' || k == 21 || k == 31) {
    if (g->readonly) {
      SetStatus("readonly: cannot undo");
      return;
    }
    UndoOnce();
    return;
  }

  if (k == 26) {
    SuspendEditor();
    return;
  }

  if (k == 'U') {
    if (g->readonly) {
      SetStatus("readonly: cannot redo");
      return;
    }
    RedoOnce();
    return;
  }

  if (k == 6) { MoveCursor(1); KeepVisible(); return; }      /* Ctrl+F */
  if (k == 2) { MoveCursor(-1); KeepVisible(); return; }     /* Ctrl+B */
  if (k == 14) { MoveCursor(bpl); KeepVisible(); return; }   /* Ctrl+N */
  if (k == 16) { MoveCursor(-bpl); KeepVisible(); return; }  /* Ctrl+P */
  if (k == K_ALT_ARROW_RIGHT) { MoveCursor(4); KeepVisible(); return; }
  if (k == K_ALT_ARROW_LEFT) { MoveCursor(-4); KeepVisible(); return; }
  if (k == K_ALT_ARROW_DOWN) { MoveCursor(4 * bpl); KeepVisible(); return; }
  if (k == K_ALT_ARROW_UP) { MoveCursor(-4 * bpl); KeepVisible(); return; }
  if (k == K_ALT_BASE + 'f' || k == K_ALT_BASE + 'F') { MoveCursor(4); KeepVisible(); return; }
  if (k == K_ALT_BASE + 'b' || k == K_ALT_BASE + 'B') { MoveCursor(-4); KeepVisible(); return; }
  if (k == K_ALT_BASE + 'n' || k == K_ALT_BASE + 'N') { MoveCursor(4 * bpl); KeepVisible(); return; }
  if (k == K_ALT_BASE + 'p' || k == K_ALT_BASE + 'P') { MoveCursor(-4 * bpl); KeepVisible(); return; }
  if (k == 1) { g->cur = (g->cur / bpl) * bpl; g->hex_half = 0; KeepVisible(); return; }  /* Ctrl+A */
  if (k == 5) {                                                 /* Ctrl+E */
    I64 line_end = (g->cur / bpl) * bpl + (bpl - 1);
    if (line_end > g->len) line_end = g->len;
    g->cur = line_end;
    g->hex_half = 0;
    KeepVisible();
    return;
  }
  if (k == 22) { MoveCursor(page); KeepVisible(); return; }  /* Ctrl+V */

  if (k == K_ARROW_LEFT || k == 'h') MoveCursor(-1);
  else if (k == K_ARROW_RIGHT || k == 'l') MoveCursor(1);
  else if (k == K_ARROW_UP || k == 'k') MoveCursor(-bpl);
  else if (k == K_ARROW_DOWN || k == 'j') MoveCursor(bpl);
  else if (k == K_PAGE_UP) MoveCursor(-page);
  else if (k == K_PAGE_DOWN) MoveCursor(page);
  else if (k == K_HOME) {
    g->cur = (g->cur / bpl) * bpl;
    g->hex_half = 0;
  }
  else if (k == K_END) {
    I64 line_end = (g->cur / bpl) * bpl + (bpl - 1);
    if (line_end > g->len) line_end = g->len;
    g->cur = line_end;
    g->hex_half = 0;
  }
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
  SetStatus("Ctrl+O open | Ctrl+W save | Ctrl+X save+quit | Ctrl+C quit | / search | v/y/Ctrl+Y mark-copy-paste");
}

I32 Main(I32 argc, U8 **argv)
{
  Editor *g = _G();
  U8 *file = NULL;
  U8 prompted_file[512];
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

  if (file && i + 1 != argc) {
    "usage: %s [options] <file>\n", argv[0];
    return 1;
  }

  if (!file) {
    I64 off = 0;
    U8 ch;
    WriteStr("file name: ");
    while (off < 511) {
      if (read(0, &ch, 1) != 1) continue;
      if (ch == '\n' || ch == '\r') break;
      prompted_file[off++] = ch;
    }
    prompted_file[off] = 0;
    if (off <= 0) {
      "no file provided\n";
      return 1;
    }
    file = prompted_file;
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
