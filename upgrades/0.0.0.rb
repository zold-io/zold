# https://github.com/zold-io/zold/issues/358
# rename all wallets from their current names into *.z

Dir.glob('*').each do |path|
  next unless path.match(/^[a-z\d]{16}$/)
  puts "Renaming #{path} -> #{path}.z"
  File.rename(path, "#{path}.z")
end
