import re

path = 'SalesAssociate/Views/SalesAssociateSalesView.swift'
with open(path, 'r') as f:
    code = f.read()

# Replace Spacing
code = re.sub(r'Spacing\.sm', '8', code)
code = re.sub(r'Spacing\.md', '16', code)
code = re.sub(r'Spacing\.lg', '24', code)
code = re.sub(r'Spacing\.xl', '32', code)
code = re.sub(r'Spacing\.xxl', '40', code)

# Replace Radius
code = re.sub(r'Radius\.sm', '8', code)
code = re.sub(r'Radius\.md', '12', code)
code = re.sub(r'Radius\.lg', '16', code)

# Replace BrandDivider -> Divider().background(Color.brandPebble)
code = re.sub(r'BrandDivider\(\)', r'Divider().background(Color.brandPebble)', code)

# Replace SectionHeader(title: "Customer") -> inline text
def repl_section(m):
    title = m.group(1).upper()
    return f'Text("{title}").font(.system(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(Color.brandWarmGrey).padding(.horizontal, 16)'

code = re.sub(r'SectionHeader\(title:\s*"([^"]+)"\)', repl_section, code)

# Fix PrimaryButton
# PrimaryButton(title: "Confirm Payment — ₹\(Int(vm.cartTotal))", isLoading: vm.isLoading)
# We will just replace PrimaryButton calls with a standard View Builder block or just define PrimaryButton at the bottom.
# Ah, defining the missing components at the bottom of the file is MUCH safer!

