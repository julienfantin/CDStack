platform :ios, '6.0'

target :release do
  link_with 'CDStack'
end

target :debug do
  link_with 'CDStack'
end

target :test, :exclusive => true do
  link_with 'CDStackTests'
  pod 'Kiwi'
end
