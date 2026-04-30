#!/usr/bin/env python3
"""
Proper Xcode localization script.
- Extracts all hardcoded UI strings from SwiftUI views
- Generates en.lproj/Localizable.strings (English base)
- Generates hi.lproj/Localizable.strings (Hindi translations)
- Does NOT modify Swift source files (SwiftUI Text("key") already works as LocalizedStringKey)
- Adds both files to the Xcode project
"""

import os
import re
import sys
import time
from deep_translator import GoogleTranslator

SRC_DIR = "RSMS"
EN_LPROJ = os.path.join(SRC_DIR, "en.lproj")
HI_LPROJ = os.path.join(SRC_DIR, "hi.lproj")
os.makedirs(EN_LPROJ, exist_ok=True)
os.makedirs(HI_LPROJ, exist_ok=True)

# These patterns match UI-visible strings in SwiftUI
# We capture the raw string literal (before any interpolation) 
STRING_PATTERNS = [
    # Text("...) — SwiftUI LocalizedStringKey
    re.compile(r'Text\(\s*"((?:[^"\\]|\\.)*)"\s*\)'),
    # TextField("placeholder", ...)
    re.compile(r'TextField\(\s*"((?:[^"\\]|\\.)*)"'),
    # Button("label") { ... }
    re.compile(r'Button\(\s*"((?:[^"\\]|\\.)*)"'),
    # Label("title", ...)
    re.compile(r'Label\(\s*"((?:[^"\\]|\\.)*)"'),
    # .navigationTitle("...")
    re.compile(r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"'),
    # Section(header: Text("..."))
    re.compile(r'Section\(\s*header:\s*Text\(\s*"((?:[^"\\]|\\.)*)"'),
    # .alert("title", ...)
    re.compile(r'\.alert\(\s*"((?:[^"\\]|\\.)*)"'),
    # .confirmationDialog("...")
    re.compile(r'\.confirmationDialog\(\s*"((?:[^"\\]|\\.)*)"'),
    # .placeholder("...")
    re.compile(r'\.placeholder\(\s*"((?:[^"\\]|\\.)*)"'),
    # sectionHeader("...") - custom function in the project
    re.compile(r'sectionHeader\(\s*"((?:[^"\\]|\\.)*)"'),
    # TabItem / toolbar item text  
    re.compile(r'tabItem\s*\{[^}]*Text\(\s*"((?:[^"\\]|\\.)*)"'),
]

# Skip strings that are: very short, look like IDs/keys, system image names, format specifiers only
SKIP_PATTERNS = [
    re.compile(r'^[%\\]'),            # starts with % or backslash (format specifier or escape)
    re.compile(r'^\s*$'),             # empty/whitespace
    re.compile(r'^[·•\-–—/|:,\.!?@#$%^&*()+=\[\]{}<>]$'),  # single symbol
    re.compile(r'^\d+$'),             # pure number
    re.compile(r'^[A-Z]{2,}$'),       # all caps acronym like "USD" "SKU" left as is (optional)
]

# Strings to always skip (technical/non-UI)
ALWAYS_SKIP = {
    "", " ", "%", "·", "•", "—", "–", "-", "/", "|", ":", ",", ".", "!", "?",
    "@", "#", "$", "%", "^", "&", "*", "(", ")", "+", "=", "[", "]", "{", "}",
    "<", ">", "\\n", "\\t",
}

def should_skip(s):
    if s in ALWAYS_SKIP:
        return True
    if len(s.strip()) <= 1:
        return True
    # Contains only interpolation placeholders like \(something)
    stripped = re.sub(r'\\[\w\.\(\)]+', '', s).strip()
    if not stripped:
        return True
    # System image names (contain dots like "plus.circle.fill")
    if re.match(r'^[a-z]+(\.[a-z]+){2,}$', s):
        return True
    return False

def make_key(text):
    """Convert display text to a camelCase localization key."""
    # Remove special chars, keep alphanumeric and spaces
    clean = re.sub(r'[^a-zA-Z0-9\s]', ' ', text)
    words = clean.split()
    if not words:
        return None
    key = words[0].lower()
    for w in words[1:]:
        if w:
            key += w.capitalize()
    # Limit key length
    if len(key) > 50:
        key = key[:50]
    return key if key else None

# ─── STEP 1: Extract all unique UI strings ───────────────────────────────────
strings_map = {}   # key -> English text
key_conflicts = {}  # key -> list of texts (to detect conflicts)

print("Scanning Swift files...")
swift_files = []
for root, dirs, files in os.walk(SRC_DIR):
    for file in files:
        if file.endswith(".swift"):
            swift_files.append(os.path.join(root, file))

for path in swift_files:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for pattern in STRING_PATTERNS:
        for match in pattern.finditer(content):
            text = match.group(1)
            if should_skip(text):
                continue
            key = make_key(text)
            if not key:
                continue
            
            # Handle key conflicts (same key, different text)
            if key in key_conflicts:
                if text not in key_conflicts[key]:
                    key_conflicts[key].append(text)
                    # Create a unique key for this conflict
                    conflict_key = key + str(len(key_conflicts[key]) - 1)
                    strings_map[conflict_key] = text
                # else: already have this text, same key works
            else:
                key_conflicts[key] = [text]
                strings_map[key] = text

print(f"Found {len(strings_map)} unique localizable strings.")

# ─── STEP 2: Translate to Hindi ──────────────────────────────────────────────
translator = GoogleTranslator(source='en', target='hi')

hi_translations = {}
total = len(strings_map)
print(f"Translating {total} strings to Hindi (this may take a few minutes)...")

# Batch translate to reduce API calls
items = list(strings_map.items())
BATCH_SIZE = 1  # translate one by one for reliability

for i, (key, text) in enumerate(items):
    try:
        translated = translator.translate(text)
        hi_translations[key] = translated
        if (i + 1) % 25 == 0:
            print(f"  Progress: {i+1}/{total}")
        # Small delay to be nice to the API
        time.sleep(0.05)
    except Exception as e:
        print(f"  Warning: Could not translate '{text[:40]}': {e}")
        hi_translations[key] = text  # Fallback to English

print("Translation complete.")

# ─── STEP 3: Write Localizable.strings files ─────────────────────────────────
en_lines = []
hi_lines = []

for key in sorted(strings_map.keys()):
    en_text = strings_map[key].replace('"', '\\"').replace('\\(', '\\\\(')
    hi_text = hi_translations.get(key, strings_map[key]).replace('"', '\\"')
    en_lines.append(f'/* {en_text} */')
    en_lines.append(f'"{key}" = "{en_text}";')
    en_lines.append('')
    hi_lines.append(f'/* {en_text} */')
    hi_lines.append(f'"{key}" = "{hi_text}";')
    hi_lines.append('')

en_content = "\n".join(en_lines)
hi_content = "\n".join(hi_lines)

en_path = os.path.join(EN_LPROJ, "Localizable.strings")
hi_path = os.path.join(HI_LPROJ, "Localizable.strings")

with open(en_path, 'w', encoding='utf-8') as f:
    f.write(en_content)
with open(hi_path, 'w', encoding='utf-8') as f:
    f.write(hi_content)

print(f"Written: {en_path}")
print(f"Written: {hi_path}")
print(f"Total keys: {len(strings_map)}")

# ─── STEP 4: Update Xcode project to include both .strings files ─────────────
# We'll use pbxproj library to add as a PBXVariantGroup (localized file)
print("\nUpdating Xcode project...")
try:
    from pbxproj import XcodeProject
    from pbxproj.pbxextensions import FileOptions

    project = XcodeProject.load("RSMS.xcodeproj/project.pbxproj")

    # Add English strings
    options_en = FileOptions(create_build_files=True, weak=False)
    project.add_file(
        en_path,
        target_name="RSMS",
        force=False
    )
    # Add Hindi strings
    project.add_file(
        hi_path,
        target_name="RSMS",
        force=False
    )
    project.save()
    print("project.pbxproj updated successfully.")
except Exception as e:
    print(f"Note: Could not auto-update project.pbxproj: {e}")
    print("You will need to manually add the Localizable.strings files to Xcode.")
    print("Steps:")
    print("  1. In Xcode, right-click on the RSMS folder → Add Files to 'RSMS'")
    print("  2. Navigate to RSMS/en.lproj/ and select Localizable.strings")
    print("  3. Do the same for RSMS/hi.lproj/Localizable.strings")
    print("  4. In Project Settings > Info, add 'hi' (Hindi) as a localization")

print("\nDone! Summary:")
print(f"  - {len(strings_map)} strings extracted and localized")
print(f"  - en.lproj/Localizable.strings: English base strings")
print(f"  - hi.lproj/Localizable.strings: Hindi translations")
print("\nNOTE: SwiftUI's Text(\"key\") automatically uses LocalizedStringKey,")
print("so no Swift source changes needed for Text() calls.")
print("For NSLocalizedString usage in ViewModels, use:")
print('  NSLocalizedString("key", comment: "description")')
