#!/usr/bin/env ruby
# frozen_string_literal: true

# Database migration to add on-premises location
REPL = true
require_relative "../loader"

def add_onprem_location
  puts "🗄️  Adding on-premises location to database..."
  
  begin
    location = Location.find_or_create(provider: "onprem", name: "onprem-01") do |loc|
      loc.display_name = "On-Premises Data Center"
      loc.visible = true
    end
    
    if location.new?
      puts "✅ Created new on-premises location:"
    else
      puts "✅ On-premises location already exists:"
    end
    
    puts "   ID: #{location.id}"
    puts "   Provider: #{location.provider}"
    puts "   Name: #{location.name}"
    puts "   Display Name: #{location.display_name}"
    puts "   Visible: #{location.visible}"
    
  rescue => e
    puts "❌ Error adding on-premises location: #{e.message}"
    exit 1
  end
end

def check_location_exists
  location = Location.where(provider: "onprem", name: "onprem-01").first
  
  if location
    puts "✅ On-premises location exists in database"
    puts "   ID: #{location.id}"
    puts "   Display Name: #{location.display_name}"
    return true
  else
    puts "❌ On-premises location not found in database"
    return false
  end
end

def remove_onprem_location
  puts "🗑️  Removing on-premises location from database..."
  
  begin
    # Check if there are any hosts using this location
    hosts = VmHost.where(location_id: Location.where(provider: "onprem").select(:id))
    
    if hosts.any?
      puts "⚠️  Warning: Found #{hosts.count} hosts using on-premises locations:"
      hosts.each do |host|
        puts "   - #{host.sshable.host} (#{host.ubid})"
      end
      
      print "Are you sure you want to remove the location? This may cause issues. (y/N): "
      return unless gets.chomp.downcase == 'y'
    end
    
    count = Location.where(provider: "onprem").delete
    
    if count > 0
      puts "✅ Removed #{count} on-premises location(s)"
    else
      puts "ℹ️  No on-premises locations found to remove"
    end
    
  rescue => e
    puts "❌ Error removing on-premises location: #{e.message}"
    exit 1
  end
end

def list_all_locations
  puts "📍 All locations in database:"
  puts "=" * 40
  
  locations = Location.order(:provider, :name)
  
  if locations.empty?
    puts "No locations found in database"
    return
  end
  
  current_provider = nil
  locations.each do |location|
    if current_provider != location.provider
      puts "\n#{location.provider.upcase}:"
      current_provider = location.provider
    end
    
    puts "  #{location.name} - #{location.display_name} (visible: #{location.visible})"
  end
end

# Main execution
case ARGV[0]
when "add"
  add_onprem_location
when "check"
  check_location_exists
when "remove"
  remove_onprem_location
when "list"
  list_all_locations
when nil
  puts "UbiCloud On-Premises Location Migration"
  puts "======================================="
  puts ""
  puts "This script manages on-premises locations in the database."
  puts ""
  puts "Usage: ruby scripts/migrate_onprem_location.rb [command]"
  puts ""
  puts "Commands:"
  puts "  add     - Add on-premises location (safe to run multiple times)"
  puts "  check   - Check if on-premises location exists"
  puts "  remove  - Remove on-premises location (WARNING: destructive)"
  puts "  list    - List all locations in database"
  puts ""
  puts "Examples:"
  puts "  ruby scripts/migrate_onprem_location.rb add"
  puts "  ruby scripts/migrate_onprem_location.rb check"
  puts ""
  puts "💡 Run 'add' after setting up UbiCloud to enable on-premises support."
else
  puts "Unknown command: #{ARGV[0]}"
  puts "Run 'ruby scripts/migrate_onprem_location.rb' for usage information."
  exit 1
end
