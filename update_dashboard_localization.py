import json
import os

XCS_PATH = "/Users/architkankaria/Desktop/Team08RSMS/RSMS/Localizable.xcstrings"

TRANSLATIONS = {
    "Orders Today": "आज के ऑर्डर",
    "Avg Order": "औसत ऑर्डर",
    "Low Stock": "कम स्टॉक",
    "Revenue": "राजस्व",
    "Weekly": "साप्ताहिक",
    "Monthly": "मासिक",
    "Yearly": "वार्षिक",
    "Today": "आज",
    "Current": "वर्तमान",
    "Previous": "पिछला",
    "Top Selling Products": "सर्वाधिक बिकने वाले उत्पाद",
    "units": "इकाइयां",
    "Staff Performance": "कर्मचारी प्रदर्शन",
    "Star Performer": "स्टार परफॉर्मर",
    "Needs Support": "सहायता की आवश्यकता",
    "orders": "ऑर्डर",
    "Low Stock Alerts": "कम स्टॉक अलर्ट",
    "Dashboard": "डैशबोर्ड",
    "Sales Dashboard": "बिक्री डैशबोर्ड",
    "Overview": "अवलोकन",
    "Loading dashboard...": "डैशबोर्ड लोड हो रहा है...",
    "%lld units": "%lld इकाइयां",
    "%lld orders": "%lld ऑर्डर",
    "Gross Sales vs Target": "कुल बिक्री बनाम लक्ष्य",
    "left": "शेष",
    "General": "सामान्य",
    "Retry": "पुनः प्रयास करें",
    "Orders": "ऑर्डर",
}

def update_xcstrings():
    if not os.path.exists(XCS_PATH):
        print(f"Error: {XCS_PATH} not found.")
        return

    with open(XCS_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    strings = data.get("strings", {})
    updated_count = 0

    for key, hi_val in TRANSLATIONS.items():
        if key in strings:
            if "localizations" not in strings[key]:
                strings[key]["localizations"] = {}
            
            # Update English if missing
            if "en" not in strings[key]["localizations"]:
                strings[key]["localizations"]["en"] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": key
                    }
                }
            
            # Update Hindi
            strings[key]["localizations"]["hi"] = {
                "stringUnit": {
                    "state": "translated",
                    "value": hi_val
                }
            }
            updated_count += 1
        else:
            # Create new key if it doesn't exist
            strings[key] = {
                "extractionState": "manual",
                "localizations": {
                    "en": {
                        "stringUnit": {
                            "state": "translated",
                            "value": key
                        }
                    },
                    "hi": {
                        "stringUnit": {
                            "state": "translated",
                            "value": hi_val
                        }
                    }
                }
            }
            updated_count += 1

    data["strings"] = strings

    with open(XCS_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"Successfully updated/added {updated_count} translations in Localizable.xcstrings.")

if __name__ == "__main__":
    update_xcstrings()
