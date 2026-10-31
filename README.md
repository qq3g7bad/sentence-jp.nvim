# 🖊 sentence-jp.nvim

**日本語**と**英語**の両方に対応したスマートなテキストオブジェクトとモーションを提供する Neovim プラグインです。

## ✨ 機能

- **日英対応**
  - 日本語 (`。！？．`) と英語 (`. ! ?`) を自動的に処理
  - カーソルから最も近い文の境界を検出
  - 混在言語のドキュメントでシームレスに動作
- **テキストオブジェクト** `is` と `as` が両言語で動作
- **モーションコマンド** `(` と `)` が両言語で動作

## ⚙️ 動作原理

プラグインは日本語と英語の両方の文末を検索します:

- **日本語:** `。！？．` (句点、感嘆符、疑問符、全角ピリオド)
- **英語:** `.!?` (ピリオド、感嘆符、疑問符)
  - 直後が行末・空白のときだけ文末とみなします（間に `)` `"` などの閉じ括弧があっても可）。`0.11` や `init.lua`、URL の途中では区切りません。

カーソルに最も近い句読点が境界として使用されます。

### 例: 混在ドキュメント

```text
これは日本語です。This is English. また日本語です。連続した
句読点や改行にも対応します。。。Consecutive punctuations...
```

- カーソルが "English" 上にある場合 → "vis" を押すと:
  - ✓  "This is English." を選択 (最も近い境界: 左側は "。", 右側は ".")
- カーソルが "日本語" 上にある場合 → "vis" を押すと:
  - ✓  "これは日本語です。" を選択 (最も近い境界: 両方とも "。")
- カーソルが "句読点" 上にある場合 → "vis" を押すと:
  - ✓  "連続した句読点や改行にも対応します。。。" を選択。

## 📦 インストール

### lazy.nvim

```lua
{
  'qq3g7bad/sentence-jp.nvim',
  config = function()
    require('sentence-jp').setup()
  end,
}
```

## 🚀 使い方

### 基本設定

```lua
require('sentence-jp').setup()
```

- `is` / `as` - テキストオブジェクト (両言語で動作)
- `)` / `(` - モーション (両言語で動作)

### テキストオブジェクトの例

```
おはようございます。Hello world. さようなら。
```

- カーソルを "Hello" に置いて `vis` を押す → "Hello world." を選択 (句読点を含む)
- カーソルを "おはよう" に置いて `vis` を押す → "おはようございます。" を選択 (句読点を含む)
- `vas` を押す → 句読点と後続のスペースを含む文を選択: "Hello world. "
- `dis` を押す → "Hello world." を削除 (ピリオドを含む)
- `cas` を押す → 句読点を含む文を変更
- `yas` を押す → 句読点を含む文をヤンク

**注意:** Vimのデフォルト `is` と同様に、これは句読点を**含みます**。後続の空白も含めるには `as` を使用してください（同じ行の空白のみ。後続の空白がなければ、Vim 標準と同様に先行する空白を含めます）。

### モーションの例

```
First. 最初の文。次の文。Last.
```

- カーソルを "First" に置いて `)` を押す → "最初" に移動 (最も近い境界は .)
- `)` を押す → "次" に移動 (最も近い境界は 。)
- `)` を押す → "Last" に移動 (最も近い境界は 。)
- `(` を押す → 前の文に戻る

文の途中の改行では止まりません。空行（段落の区切り）では Vim 標準と同様に止まります。

### モーション x オペレータ

モーションとオペレータを組み合わせる：

- `d)` - 次の文まで削除
- `c(` - 前の文まで変更
- `y)` - 次の文までヤンク
- `v)` - 次の文まで視覚選択

## ⚙️ 設定

### カスタム句読点

```lua
require('sentence-jp').setup({
  punctuation = {
    sentence_endings_jp = '[。！？．‼⁉]',  -- 和文の文末に ‼ ⁉ を追加
    -- sentence_endings_en = '[.!?]',     -- 英文の文末 (既定値)
  },
})
```

### かぎ括弧・閉じ括弧

`彼は「行く。」と言った。` のように、句読点の直後に閉じ括弧があり、その後ろに文が続く場合は、引用内の句読点とみなして文を区切りません。
閉じ括弧の後ろが行末・空白・別の句読点・開き括弧（`「はい。」「いいえ。」`）なら、閉じ括弧までを 1 文とします。

```lua
require('sentence-jp').setup({
  punctuation = {
    closing = '[」』）】〉》〕］｝"\'”’)\\]]',  -- 閉じ括弧として扱う文字（既定値）
  },
  quote_aware = false,  -- 「。」」の直後で常に文を区切る（既定: true）
})
```

### 異なるモーションキー

```lua
require('sentence-jp').setup({
  motions = {
    next_sentence = ']s',  -- ) の代わりに ]s を使用
    prev_sentence = '[s',  -- ( の代わりに [s を使用
  },
})
```

### 機能を無効化

```lua
require('sentence-jp').setup({
  textobject = {
    enable = false,  -- is/as を無効化
  },
  motions = {
    enable = false,  -- ) / ( を無効化
  },
})
```

## 🔧 トラブルシューティング

### テキストオブジェクトが動作しない

1. 設定で `setup()` を呼び出したことを確認してください
2. 競合するキーマップがないか確認: `:verbose map is`
3. プラグインが読み込まれたか確認: `:lua print(vim.inspect(require('sentence-jp').get_config()))`

### モーションが間違った場所にジャンプする

1. 句読点パターンがテキストと一致しているか確認してください
2. 全角スペース処理を確認: `include_fullwidth_space = true`
3. まず純粋な日本語または純粋な英語のテキストでテストしてください

## 🙏 クレジット

- [jasentence.vim](https://github.com/deton/jasentence.vim)

---

<details>
<summary>📖 English Documentation</summary>

# sentence-jp.nvim

A Neovim plugin that provides smart sentence text objects and motions for **both Japanese and English**. Just install and use - no configuration needed!

## ✨ Features

- **Smart multi-language sentence detection**
  - Automatically handles Japanese (`。！？．`) and English (`. ! ?`)
  - Finds NEAREST sentence boundary from cursor
  - Works seamlessly in mixed-language documents
- **Text objects** `is` and `as` work for BOTH languages
- **Motion commands** `(` and `)` work for BOTH languages

## ⚙️ How It Works

The plugin searches for BOTH Japanese and English punctuation:

- **Japanese:** `。！？．` (period, exclamation, question, fullwidth period)
- **English:** `.!?` (period, exclamation, question)
  - Only treated as a sentence end when followed by end of line or whitespace (optionally after closers such as `)` or `"`), so `0.11`, `init.lua` and URLs are not split.

Whichever punctuation is NEAREST to your cursor is used for boundaries.

### Example: Mixed Document

```text
これは日本語です。This is English. また日本語です。連続した
句読点や改行にも対応します。。。Consecutive punctuations...
```

- Cursor on "English" → Press "vis":
  - ✓  Selects "This is English." (nearest boundaries: 。and .)
- Cursor on "日本語" → Press "vis":
  - ✓  Selects "これは日本語です。" (nearest boundaries: both 。)
- Cursor on "句読点" → Press "vis":
  - ✓  Selects "連続した句読点や改行にも対応します。。。"

## 📦 Installation

### lazy.nvim

```lua
{
  'qq3g7bad/sentence-jp.nvim',
  config = function()
    require('sentence-jp').setup()
  end,
}
```

## 🚀 Usage

### Basic Setup

```lua
require('sentence-jp').setup()
```

That's it! Works for both Japanese and English.

Now you can use:

- `is` / `as` - Text objects (work for both languages)
- `)` / `(` - Motions (work for both languages)

### Text Object Examples

Given this mixed text:

```
おはようございます。Hello world. さようなら。
```

- Place cursor on "Hello" and press `vis` → selects "Hello world." (includes punctuation)
- Place cursor on "おはよう" and press `vis` → selects "おはようございます。" (includes punctuation)
- Press `vas` → selects sentence with punctuation AND trailing space: "Hello world. "
- Press `dis` → deletes "Hello world." (including the period)
- Press `cas` → changes sentence with punctuation
- Press `yas` → yanks sentence with punctuation

**Note:** Just like Vim's default `is`, this INCLUDES the punctuation mark. Use `as` to also include trailing whitespace (on the same line only; if there is none, the leading whitespace is included instead, like Vim).

### Motion Examples

Given this text:

```
First. 最初の文。次の文。Last.
```

- Cursor on "First", press `)` → moves to "最初" (nearest boundary is .)
- Press `)` → moves to "次" (nearest boundary is 。)
- Press `)` → moves to "Last" (nearest boundary is 。)
- Press `(` → moves back to previous sentence

Line breaks inside a sentence are skipped. Blank lines (paragraph boundaries) are stops, just like Vim.

### Operator-Pending Mode

Combine motions with operators:

- `d)` - delete to next sentence
- `c(` - change to previous sentence
- `y)` - yank to next sentence
- `v)` - visually select to next sentence

## ⚙️ Configuration

### Custom Punctuation

Want to add more punctuation marks?

```lua
require('sentence-jp').setup({
  punctuation = {
    sentence_endings_jp = '[。！？．‼⁉]',  -- add ‼ ⁉ as Japanese sentence endings
    -- sentence_endings_en = '[.!?]',     -- English sentence endings (default)
  },
})
```

### Quotes and Closing Brackets

When a closing bracket follows sentence-ending punctuation and the sentence continues after it (`彼は「行く。」と言った。`), the punctuation is treated as part of a quote and does not end the sentence.
If the closer is followed by end of line, whitespace, another ending or an opening bracket (`「はい。」「いいえ。」`), the sentence ends after the closer.

```lua
require('sentence-jp').setup({
  punctuation = {
    closing = '[」』）】〉》〕］｝"\'”’)\\]]',  -- characters treated as closers (default)
  },
  quote_aware = false,  -- always end the sentence after "。」" (default: true)
})
```

### Different Motion Keys

Prefer different keys for motions?

```lua
require('sentence-jp').setup({
  motions = {
    next_sentence = ']s',  -- Use ]s instead of )
    prev_sentence = '[s',  -- Use [s instead of (
  },
})
```

### Disable Features

```lua
require('sentence-jp').setup({
  textobject = {
    enable = false,  -- Disable is/as
  },
  motions = {
    enable = false,  -- Disable ) / (
  },
})
```

## 🔧 Troubleshooting

### Text objects not working

1. Make sure you've called `setup()` in your config
2. Check if there are conflicting keymaps: `:verbose map is`
3. Verify the plugin loaded: `:lua print(vim.inspect(require('sentence-jp').get_config()))`

### Motions jumping to wrong places

1. Check your punctuation patterns match your text
2. Verify fullwidth space handling: `include_fullwidth_space = true`
3. Test with pure Japanese or pure English text first

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 🙏 Credits

- Inspired by [jasentence.vim](https://github.com/deton/jasentence.vim) by deton.

</details>
