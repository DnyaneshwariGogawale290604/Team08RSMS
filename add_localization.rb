require 'securerandom'

pbx = File.read('RSMS.xcodeproj/project.pbxproj')

if pbx.include?('Localizable.strings')
  puts 'Already contains Localizable.strings — skipping.'
  exit 0
end

en_ref = SecureRandom.uuid.upcase.delete('-')[0,24]
hi_ref = SecureRandom.uuid.upcase.delete('-')[0,24]
vg_ref = SecureRandom.uuid.upcase.delete('-')[0,24]
bf_ref = SecureRandom.uuid.upcase.delete('-')[0,24]

# 1. PBXFileReference entries
en_file_ref = "\t\t#{en_ref} = {isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = en; path = en.lproj/Localizable.strings; sourceTree = \"<group>\"; };\n"
hi_file_ref = "\t\t#{hi_ref} = {isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = hi; path = hi.lproj/Localizable.strings; sourceTree = \"<group>\"; };\n"
pbx.sub!('/* End PBXFileReference section */', en_file_ref + hi_file_ref + '/* End PBXFileReference section */')

# 2. PBXVariantGroup
vg_block = "\t\t#{vg_ref} = {\n\t\t\tisa = PBXVariantGroup;\n\t\t\tchildren = (\n\t\t\t\t#{en_ref} /* en */,\n\t\t\t\t#{hi_ref} /* hi */,\n\t\t\t);\n\t\t\tname = Localizable.strings;\n\t\t\tsourceTree = \"<group>\";\n\t\t};\n"
if pbx.include?('/* End PBXVariantGroup section */')
  pbx.sub!('/* End PBXVariantGroup section */', vg_block + '/* End PBXVariantGroup section */')
else
  # insert before End PBXGroup section
  pbx.sub!('/* End PBXGroup section */', vg_block + '/* End PBXGroup section */')
end

# 3. PBXBuildFile
bf_line = "\t\t#{bf_ref} = {isa = PBXBuildFile; fileRef = #{vg_ref} /* Localizable.strings */; };\n"
pbx.sub!('/* End PBXBuildFile section */', bf_line + '/* End PBXBuildFile section */')

# 4. Add to Resources build phase (find PBXResourcesBuildPhase files list)
pbx.sub!(/PBXResourcesBuildPhase.*?files = \(/m) do |m|
  m + "\n\t\t\t\t#{bf_ref} /* Localizable.strings in Resources */,"
end

File.write('RSMS.xcodeproj/project.pbxproj', pbx)
puts "project.pbxproj updated."
puts "vg=#{vg_ref} en=#{en_ref} hi=#{hi_ref}"
