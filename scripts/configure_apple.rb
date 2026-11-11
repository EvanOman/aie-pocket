#!/usr/bin/env ruby
# Usage: BUNDLE_ID=com.yourname.aieWatch DEVELOPMENT_TEAM=ABCDE12345 ruby scripts/configure_apple.rb
require 'xcodeproj'
require 'pathname'
require 'json'

abort 'Usage: ruby scripts/configure_apple.rb [--check]' unless ARGV.empty? || ARGV == ['--check']

root = Pathname.new(__dir__).parent
project_path = root.join('ios/Runner.xcodeproj')
abort 'Generate the Flutter iOS scaffold before configuring Apple targets.' unless project_path.directory?
project = Xcodeproj::Project.open(project_path)
phone = project.targets.find { |target| target.name == 'Runner' }
abort 'Expected Flutter Runner target.' unless phone

if ARGV == ['--check']
  errors = []
  check = ->(condition, message) { errors << message unless condition }
  watch = project.targets.find { |target| target.name == 'AIEWatch' }
  widget = project.targets.find { |target| target.name == 'AIEComplication' }
  abort 'Apple project check failed: AIEWatch or AIEComplication target is missing.' unless watch && widget
  check.call(watch.product_type == 'com.apple.product-type.application', 'AIEWatch must be a watchOS application.')
  check.call(widget.product_type == 'com.apple.product-type.app-extension', 'AIEComplication must be an app extension.')
  expected_sources = {
    phone => %w[AppDelegate.swift ScheduleBridge.swift Shared/ScheduleSnapshot.swift],
    watch => %w[Shared/ScheduleSnapshot.swift App/AIEWatchApp.swift App/ScheduleStore.swift App/TalkCardsView.swift],
    widget => %w[Shared/ScheduleSnapshot.swift Complication/ScheduleComplication.swift]
  }
  expected_sources.each do |target, paths|
    references = target.source_build_phase.files_references
    paths.each { |path| check.call(references.any? { |reference| reference.path == path }, "#{target.name} is missing source #{path}.") }
    references.each { |reference| check.call(reference.real_path.file?, "Source file does not exist: #{reference.real_path}") }
    check.call(references.map(&:uuid).uniq.size == references.size, "#{target.name} has duplicate source entries.")
    check.call(target.build_configurations.map(&:name).sort == project.build_configurations.map(&:name).sort, "#{target.name} is missing a project build configuration.")
  end
  [[phone, watch, 'Embed Watch Content', '16', '$(CONTENTS_FOLDER_PATH)/Watch'],
   [watch, widget, 'Embed App Extensions', '13', '']].each do |parent, child, name, destination, folder|
    check.call(parent.dependencies.any? { |dependency| dependency.target == child }, "#{parent.name} must depend on #{child.name}.")
    phases = parent.copy_files_build_phases.select { |phase| phase.name == name }
    check.call(phases.size == 1, "#{parent.name} needs exactly one #{name} phase.")
    phase = phases.first
    check.call(phase && phase.dst_subfolder_spec == destination && phase.dst_path == folder, "#{name} has the wrong destination.")
    check.call(phase && phase.files_references.count { |reference| reference == child.product_reference } == 1, "#{name} must embed #{child.product_name} exactly once.")
  end
  watch_embedding = phone.copy_files_build_phases.find { |phase| phase.name == 'Embed Watch Content' }
  thin_binary = phone.shell_script_build_phases.find { |phase| phase.name == 'Thin Binary' }
  check.call(!thin_binary || (watch_embedding && phone.build_phases.index(watch_embedding) < phone.build_phases.index(thin_binary)), 'Runner must embed watch content before Thin Binary to avoid an Info.plist build cycle.')
  [watch, widget].each do |target|
    capability = project.root_object.attributes.dig('TargetAttributes', target.uuid, 'SystemCapabilities', 'com.apple.ApplicationGroups.iOS', 'enabled')
    check.call(capability.to_s == '1', "#{target.name} is missing the App Groups capability.")
    target.build_configurations.each do |configuration|
      settings = configuration.build_settings
      phone_settings = phone.build_configurations.find { |item| item.name == configuration.name }&.build_settings || {}
      phone_id = phone_settings['PRODUCT_BUNDLE_IDENTIFIER']
      suffix = target == watch ? '.watch' : '.watch.widgets'
      check.call(settings['PRODUCT_BUNDLE_IDENTIFIER'] == "#{phone_id}#{suffix}", "#{target.name}/#{configuration.name} has an invalid bundle relationship.")
      check.call(settings['PHONE_BUNDLE_IDENTIFIER'] == phone_id, "#{target.name}/#{configuration.name} has the wrong companion ID.")
      check.call(settings['SDKROOT'] == 'watchos' && settings['TARGETED_DEVICE_FAMILY'] == '4', "#{target.name}/#{configuration.name} must use the watchOS SDK and device family.")
      group = settings['SCHEDULE_APP_GROUP']
      other = (target == watch ? widget : watch).build_configurations.find { |item| item.name == configuration.name }
      check.call(group&.start_with?('group.') && other&.build_settings&.fetch('SCHEDULE_APP_GROUP', nil) == group, "#{configuration.name} watch App Groups differ or are missing.")
      check.call(settings['APPLICATION_EXTENSION_API_ONLY'] == 'YES', 'The complication must restrict extension-unsafe APIs.') if target == widget
      %w[INFOPLIST_FILE CODE_SIGN_ENTITLEMENTS].each do |setting|
        filename = settings[setting]
        path = filename && root.join('ios', filename)
        unless path&.file?
          errors << "#{target.name}/#{configuration.name} has no valid #{setting}."
          next
        end
        begin
          plist = Xcodeproj::Plist.read_from_path(path)
          if setting == 'CODE_SIGN_ENTITLEMENTS'
            check.call(plist['com.apple.security.application-groups'] == ['$(SCHEDULE_APP_GROUP)'], "#{path.basename} must use the configured App Group.")
          else
            check.call(plist['ScheduleAppGroup'] == '$(SCHEDULE_APP_GROUP)', "#{path.basename} must expose ScheduleAppGroup.")
            if target == watch
              check.call(plist['WKApplication'] == true && plist['WKCompanionAppBundleIdentifier'] == '$(PHONE_BUNDLE_IDENTIFIER)', 'Watch Info.plist is missing the app/companion relationship.')
              schemes = (plist['CFBundleURLTypes'] || []).flat_map { |item| item['CFBundleURLSchemes'] || [] }
              check.call(schemes.include?('aiewatch'), 'Watch Info.plist must register aiewatch links.')
            else
              check.call(plist.dig('NSExtension', 'NSExtensionPointIdentifier') == 'com.apple.widgetkit-extension', 'Complication Info.plist is not a WidgetKit extension.')
            end
          end
        rescue StandardError => error
          errors << "Cannot parse #{path}: #{error.message}"
        end
      end
    end
  end
  check.call(watch.resources_build_phase.files_references.any? { |reference| reference.path == 'Assets.xcassets' && reference.real_path.directory? }, 'The watch asset catalogue is missing from resources.')
  begin
    icon_path = root.join('watch/Assets.xcassets/AppIcon.appiconset')
    icons = JSON.parse(icon_path.join('Contents.json').read).fetch('images')
    check.call(icons.any? { |icon| icon['filename'] && icon_path.join(icon['filename']).file? }, 'The watch app icon is missing.')
  rescue StandardError => error
    errors << "Cannot read watch icon assets: #{error.message}"
  end
  scheme_path = project_path.join('xcshareddata/xcschemes/AIEWatch.xcscheme')
  check.call(scheme_path.file? && scheme_path.read.include?(watch.uuid), 'The shared AIEWatch scheme is missing or points at the wrong target.')
  check.call(root.join('ios/Podfile').file?, 'The Flutter CocoaPods Podfile is missing.')
  unless errors.empty?
    abort "Apple project check failed:\n- #{errors.uniq.join("\n- ")}"
  end
  puts 'Apple project check passed: source files, targets, plists, bundle IDs, App Groups, URL scheme, assets, and embedding are valid. No files changed.'
  puts 'This is a static check; Xcode compilation and paired-device transfer remain separate checks.'
  exit
end

existing_id = phone.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
bundle_id = ENV.fetch('BUNDLE_ID', existing_id || 'com.example.aiepocket')
abort 'BUNDLE_ID must be a reverse-DNS identifier.' unless bundle_id.match?(/\A[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)+\z/)
app_group = ENV.fetch('APP_GROUP', "group.#{bundle_id}")
abort 'APP_GROUP must be a group.* identifier.' unless app_group.match?(/\Agroup\.[A-Za-z0-9.-]+\z/)
team = ENV['DEVELOPMENT_TEAM']
version = root.join('pubspec.yaml').read[/^version:\s*([^\s]+)/, 1] || '1.0.0+1'
marketing_version, build_number = version.split('+', 2)

watch = project.targets.find { |target| target.name == 'AIEWatch' } || project.new_target(:application, 'AIEWatch', :watchos, '10.0', nil, :swift)
widget = project.targets.find { |target| target.name == 'AIEComplication' } || project.new_target(:app_extension, 'AIEComplication', :watchos, '10.0', nil, :swift)
watch_group = project.main_group.find_subpath('Watch', false) || project.main_group.new_group('Watch', '../watch')
runner_group = project.main_group.find_subpath('Runner', false)

def add_source(group, path, targets)
  reference = group.files.find { |file| file.path == path } || group.new_file(path)
  targets.each { |target| target.source_build_phase.add_file_reference(reference, true) }
end

add_source(watch_group, 'Shared/ScheduleSnapshot.swift', [phone, watch, widget])
%w[AIEWatchApp.swift ScheduleStore.swift TalkCardsView.swift].each do |filename|
  add_source(watch_group, "App/#{filename}", [watch])
end
add_source(watch_group, 'Complication/ScheduleComplication.swift', [widget])
add_source(runner_group, 'ScheduleBridge.swift', [phone])

assets = watch_group.files.find { |file| file.path == 'Assets.xcassets' } || watch_group.new_file('Assets.xcassets')
watch.resources_build_phase.add_file_reference(assets, true)
%w[Watch-Info.plist Complication-Info.plist Watch.entitlements Complication.entitlements].each do |path|
  watch_group.new_file(path) unless watch_group.files.any? { |file| file.path == path }
end

# SDKROOT-relative framework references work with the selected installed SDK.
def add_framework(project, target, name)
  path = "System/Library/Frameworks/#{name}.framework"
  reference = project.frameworks_group.files.find { |file| file.path == path } || project.frameworks_group.new_file(path, :sdk_root)
  target.frameworks_build_phase.add_file_reference(reference, true)
end
[watch, widget].each do |target|
  target.frameworks_build_phase.files.to_a.each do |build_file|
    build_file.remove_from_project if build_file.file_ref&.path&.include?('Platforms/WatchOS.platform')
  end
end
add_framework(project, phone, 'WatchConnectivity')
%w[Foundation SwiftUI WatchConnectivity WidgetKit].each { |name| add_framework(project, watch, name) }
%w[Foundation SwiftUI WidgetKit].each { |name| add_framework(project, widget, name) }

[watch, widget].each do |target|
  project.build_configurations.each do |configuration|
    type = configuration.type || (configuration.name == 'Debug' ? :debug : :release)
    target.add_build_configuration(configuration.name, type)
  end
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings.merge!(
      'SDKROOT' => 'watchos', 'SUPPORTED_PLATFORMS' => 'watchos watchsimulator',
      'WATCHOS_DEPLOYMENT_TARGET' => '10.0', 'TARGETED_DEVICE_FAMILY' => '4',
      'SWIFT_VERSION' => '5.0', 'CODE_SIGN_STYLE' => 'Automatic',
      'GENERATE_INFOPLIST_FILE' => 'NO', 'SKIP_INSTALL' => 'YES',
      'MARKETING_VERSION' => marketing_version, 'CURRENT_PROJECT_VERSION' => build_number || '1',
      'SCHEDULE_APP_GROUP' => app_group, 'PHONE_BUNDLE_IDENTIFIER' => bundle_id,
      'PRODUCT_NAME' => '$(TARGET_NAME)', 'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO'
    )
    settings['DEVELOPMENT_TEAM'] = team if team && !team.empty?
    settings.delete('IPHONEOS_DEPLOYMENT_TARGET')
    settings.delete('ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME')
    settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if configuration.name == 'Debug'
  end
  attributes = project.root_object.attributes['TargetAttributes'] ||= {}
  attributes[target.uuid] ||= {}
  attributes[target.uuid]['SystemCapabilities'] ||= {}
  attributes[target.uuid]['SystemCapabilities']['com.apple.ApplicationGroups.iOS'] = { 'enabled' => 1 }
end
watch.build_configurations.each do |configuration|
  configuration.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => "#{bundle_id}.watch",
    'INFOPLIST_FILE' => '../watch/Watch-Info.plist',
    'CODE_SIGN_ENTITLEMENTS' => '../watch/Watch.entitlements',
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
    'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks'],
    'ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES' => 'YES'
  )
end
widget.build_configurations.each do |configuration|
  configuration.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => "#{bundle_id}.watch.widgets",
    'INFOPLIST_FILE' => '../watch/Complication-Info.plist',
    'CODE_SIGN_ENTITLEMENTS' => '../watch/Complication.entitlements',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  )
end
phone.build_configurations.each do |configuration|
  configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  configuration.build_settings['DEVELOPMENT_TEAM'] = team if team && !team.empty?
end
project.targets.select { |target| target.name == 'RunnerTests' }.each do |target|
  target.build_configurations.each { |configuration| configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle_id}.RunnerTests" }
end
project.targets.select { |target| target.name == 'AIEWatchUITests' }.each do |target|
  target.build_configurations.each { |configuration| configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle_id}.watch.uitests" }
end

def embed(parent, child, name, destination, folder)
  phase = parent.copy_files_build_phases.find { |item| item.name == name } || parent.new_copy_files_build_phase(name)
  phase.dst_subfolder_spec = destination
  phase.dst_path = folder
  file = phase.add_file_reference(child.product_reference, true)
  file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  parent.add_dependency(child)
end
embed(phone, watch, 'Embed Watch Content', '16', '$(CONTENTS_FOLDER_PATH)/Watch')
embed(watch, widget, 'Embed App Extensions', '13', '')

# Thin Binary reads Runner's processed Info.plist, which depends on embedded watch content.
watch_embedding = phone.copy_files_build_phases.find { |phase| phase.name == 'Embed Watch Content' }
thin_binary = phone.shell_script_build_phases.find { |phase| phase.name == 'Thin Binary' }
if thin_binary && phone.build_phases.index(watch_embedding) > phone.build_phases.index(thin_binary)
  phone.build_phases.delete(watch_embedding)
  phone.build_phases.insert(phone.build_phases.index(thin_binary), watch_embedding)
end

project.save
scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(watch, nil, launch_target: true)
scheme.save_as(project_path, 'AIEWatch', true)
puts "Configured Runner → AIEWatch → AIEComplication for #{bundle_id}; app group #{app_group}."
puts 'Xcode build and paired-device validation still require macOS.'
