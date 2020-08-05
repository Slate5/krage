# Rakefile
desc 'Install Krage'
task default: [:install]

task :configure do
  puts 'Configuring...'
  unless system('which dconf >/dev/null 2>&1')
    puts "\e[31mInstall `dconf` before installing `krage`\e[39m"
    exit 1
  end
  home = `echo -n $HOME`
  @krage_dir = File.expand_path(__dir__)
  @app_icon_dir = "#{home}/.local/share/icons/"
  @app_desktop_dir = "#{home}/.local/share/applications/"
  chmod 0755, "#{@krage_dir}/bin/krage"
  `chmod 755 #{@krage_dir}/ext/gen*`
end

task :clean => [:configure] do
  puts 'Cleaning...'
  old_krage_path = `readlink -fn /usr/local/bin/krage`.sub(/\/bin\/krage/, '')
  unless ['', '/usr/local', @krage_dir].any?(old_krage_path)
    puts "\e[4mRemoving previous Krage installation\e[24m: "
    Dir.chdir(old_krage_path) do
      system('rake uninstall')
    end
    puts "\e[4mPrevious Krage installation removed\e[24m"
    next
  end
  `sudo rm -f /usr/local/bin/krage`
  rm_f("#{@app_desktop_dir}krage.desktop")
  rm_f("#{@app_icon_dir}krage_crow.png")
  unless `dconf dump /org/gnome/terminal/legacy/profiles:/ | grep 'Krage'`.empty?
    begin
      krage_profile_id = File.read("#{@krage_dir}/ext/.current_krage_id")  
    rescue Exception => e
      abort("#{e}:\n\e[4mDelete terminal's profile \"Krage\" manually and rerun rake\e[24m")
    end

    `dconf reset -f /org/gnome/terminal/legacy/profiles:/:#{krage_profile_id}/`

    user_profile = `dconf dump /org/gnome/terminal/legacy/profiles:/`
    user_profile.gsub!(/(, )?'#{krage_profile_id}'(, )?/, '\2')

    `echo -n "#{user_profile}" > #{@krage_dir}/ext/.user_profile.dconf`

    `dconf load /org/gnome/terminal/legacy/profiles:/ < #{@krage_dir}/ext/.user_profile.dconf`
    `rm #{@krage_dir}/ext/.??*`
  end
end

desc 'Uninstall Krage'
task :uninstall => [:clean] do
  puts 'Uninstalling Krage...'
  rm_rf(@krage_dir)
end

task :install => [:clean] do
  puts 'Installing Krage...'
  `sudo ln -s #{@krage_dir}/bin/krage '/usr/local/bin'`
  mkdir_p @app_icon_dir
  ln_s("#{@krage_dir}/data/krage_crow.png", @app_icon_dir)
  ln_s("#{@krage_dir}/ext/krage.desktop", @app_desktop_dir)
end
