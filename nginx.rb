require 'formula'
require 'digest/sha1'

class Nginx < Formula
  homepage 'http://nginx.org/'
  url 'http://nginx.org/download/nginx-1.0.14.tar.gz'
  md5 '019844e48c34952253ca26dd6e28c35c'

  devel do
    url 'http://nginx.org/download/nginx-1.1.17.tar.gz'
    md5 'b4c1c855d130352586ffc9a945ea6c00'
  end

  depends_on 'pcre'

  skip_clean 'logs'

  # Changes default port to 8080
  # Tell configure to look for pcre in HOMEBREW_PREFIX
  def patches
    DATA
  end

  def options
    [
      ['--with-passenger', "Compile with support for Phusion Passenger module"],
      ['--with-webdav',    "Compile with support for WebDAV module"],
      ['--with-mod-zip',   "Compile with support for mod-zip module"]
    ]
  end

  def passenger_config_args
    passenger_root = `passenger-config --root`.chomp

    if File.directory?(passenger_root)
      return "--add-module=#{passenger_root}/ext/nginx"
    end

    puts "Unable to install nginx with passenger support. The passenger"
    puts "gem must be installed and passenger-config must be in your path"
    puts "in order to continue."
    exit
  end

  def mod_zip_install
    file_path = File.join(Dir.getwd, "mod_zip-1.1.6.tar.gz")
    sha_expected = "b241e624cf98c3ae45d289df20df1132ab4f76d5"

    system "/usr/bin/curl -O http://mod-zip.googlecode.com/files/mod_zip-1.1.6.tar.gz"
    sha_result = Digest::SHA1.file(file_path).to_s

    if sha_expected != sha_result
      onoe "Unable to install nginx with mod-zip support."
      exit
    end

    system "/usr/bin/tar -xvf #{file_path}"
    return File.join(File.dirname(file_path), File.basename(file_path, '.tar.gz'))
  end

  def install
    args = ["--prefix=#{prefix}",
            "--with-http_ssl_module",
            "--with-pcre",
            "--conf-path=#{etc}/nginx/nginx.conf",
            "--pid-path=#{var}/run/nginx.pid",
            "--lock-path=#{var}/nginx/nginx.lock"]

    args << passenger_config_args           if ARGV.include? '--with-passenger'
    args << "--with-http_dav_module"        if ARGV.include? '--with-webdav'

    if ARGV.include? '--with-mod-zip'
      mod_zip_path = mod_zip_install
      args << "--add-module=#{mod_zip_path}" 
    end

    system "./configure", *args
    system "make"
    system "make install"
    man8.install "objs/nginx.8"

    plist_path.write startup_plist
    plist_path.chmod 0644
  end

  def caveats; <<-EOS.undent
    In the interest of allowing you to run `nginx` without `sudo`, the default
    port is set to localhost:8080.

    If you want to host pages on your local machine to the public, you should
    change that to localhost:80, and run `sudo nginx`. You'll need to turn off
    any other web servers running port 80, of course.

    You can start nginx automatically on login running as your user with:
      mkdir -p ~/Library/LaunchAgents
      cp #{plist_path} ~/Library/LaunchAgents/
      launchctl load -w ~/Library/LaunchAgents/#{plist_path.basename}

    Though note that if running as your user, the launch agent will fail if you
    try to use a port below 1024 (such as http's default of 80.)
    EOS
  end

  def startup_plist
    return <<-EOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>#{plist_name}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>UserName</key>
    <string>#{`whoami`.chomp}</string>
    <key>ProgramArguments</key>
    <array>
        <string>#{HOMEBREW_PREFIX}/sbin/nginx</string>
        <string>-g</string>
        <string>daemon off;</string>
    </array>
    <key>WorkingDirectory</key>
    <string>#{HOMEBREW_PREFIX}</string>
  </dict>
</plist>
    EOPLIST
  end
end

__END__
--- a/auto/lib/pcre/conf
+++ b/auto/lib/pcre/conf
@@ -155,6 +155,21 @@ else
             . auto/feature
         fi

+        if [ $ngx_found = no ]; then
+
+            # Homebrew
+            ngx_feature="PCRE library in HOMEBREW_PREFIX"
+            ngx_feature_path="HOMEBREW_PREFIX/include"
+
+            if [ $NGX_RPATH = YES ]; then
+                ngx_feature_libs="-RHOMEBREW_PREFIX/lib -LHOMEBREW_PREFIX/lib -lpcre"
+            else
+                ngx_feature_libs="-LHOMEBREW_PREFIX/lib -lpcre"
+            fi
+
+            . auto/feature
+        fi
+
         if [ $ngx_found = yes ]; then
             CORE_DEPS="$CORE_DEPS $REGEX_DEPS"
             CORE_SRCS="$CORE_SRCS $REGEX_SRCS"
--- a/conf/nginx.conf
+++ b/conf/nginx.conf
@@ -33,7 +33,7 @@
     #gzip  on;

     server {
-        listen       80;
+        listen       8080;
         server_name  localhost;

         #charset koi8-r;
