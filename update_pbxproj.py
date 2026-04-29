import re

path = '/Users/dnyaneshwari/Documents/Projects/RSMS/RSMS.xcodeproj/project.pbxproj'
with open(path, 'r') as f:
    content = f.read()

replacement = """INFOPLIST_KEY_CFBundleURLTypes = (
					{
						CFBundleTypeRole = Editor;
						CFBundleURLName = "com.rsms.deep";
						CFBundleURLSchemes = (
							rsms,
						);
					},
				);
				INFOPLIST_KEY_NSCameraUsageDescription"""

content = re.sub(r'INFOPLIST_KEY_NSCameraUsageDescription', replacement, content)

with open(path, 'w') as f:
    f.write(content)
