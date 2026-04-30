import os
import re
from deep_translator import GoogleTranslator
from pbxproj import XcodeProject

# Setup Translator
translator = GoogleTranslator(source='en', target='hi')

# Regex patterns to find hardcoded strings
patterns = [
    (re.compile(r'Text\(\s*"([^"\\]+)"\s*\)'), 'Text("{}")'),
    (re.compile(r'Button\(\s*"([^"\\]+)"'), 'Button("{}")'),
    (re.compile(r'Label\(\s*"([^"\\]+)"'), 'Label("{}")'),
    (re.compile(r'\.navigationTitle\(\s*"([^"\\]+)"\s*\)'), '.navigationTitle("{}")')
]

strings_map = {}
def generate_key(text):
    words = re.findall(r'[A-Za-z0-9]+', text)
    if not words: return "empty_key"
    key = words[0].lower() + "".join(word.capitalize() for word in words[1:])
    return key

# Directories to process
src_dir = "RSMS"

for root, dirs, files in os.walk(src_dir):
    for file in files:
        if file.endswith(".swift"):
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()

            original_content = content
            for regex, replacement in patterns:
                def repl(match):
                    original_text = match.group(1)
                    # skip if it's already looking like a key (camelCase with no spaces) and no uppercase first letter
                    # or if it's too short
                    if len(original_text) <= 1: return match.group(0)
                    
                    key = generate_key(original_text)
                    # Handle duplicate keys with different text
                    if key in strings_map and strings_map[key] != original_text:
                        key = key + "_" + str(hash(original_text))[-4:]
                    strings_map[key] = original_text
                    return match.group(0).replace(f'"{original_text}"', f'"{key}"')

                content = regex.sub(repl, content)

            if content != original_content:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Updated {path}")

# Generate Localizable.strings
en_lproj_dir = os.path.join(src_dir, "en.lproj")
hi_lproj_dir = os.path.join(src_dir, "hi.lproj")
os.makedirs(en_lproj_dir, exist_ok=True)
os.makedirs(hi_lproj_dir, exist_ok=True)

en_strings = []
hi_strings = []

print(f"Translating {len(strings_map)} strings...")
for key, text in strings_map.items():
    en_strings.append(f'"{key}" = "{text}";')
    try:
        translated = translator.translate(text)
        hi_strings.append(f'"{key}" = "{translated}";')
    except Exception as e:
        print(f"Translation failed for {text}: {e}")
        hi_strings.append(f'"{key}" = "{text}";')

with open(os.path.join(en_lproj_dir, "Localizable.strings"), 'w', encoding='utf-8') as f:
    f.write("\n".join(en_strings))
    
with open(os.path.join(hi_lproj_dir, "Localizable.strings"), 'w', encoding='utf-8') as f:
    f.write("\n".join(hi_strings))

print("Strings files generated.")

# Update pbxproj
project_path = "RSMS.xcodeproj/project.pbxproj"
try:
    project = XcodeProject.load(project_path)
    
    # Check if a variant group for Localizable.strings exists, or create files
    # pbxproj library doesn't easily handle PBXVariantGroup for localizations cleanly, 
    # but we can try adding them as normal files if they don't exist
    project.add_file(os.path.join(en_lproj_dir, "Localizable.strings"), force=False)
    project.add_file(os.path.join(hi_lproj_dir, "Localizable.strings"), force=False)
    
    project.save()
    print("Updated project.pbxproj")
except Exception as e:
    print(f"Failed to update pbxproj: {e}")

