# encoding: utf-8


require 'watir-webdriver'
require 'json'
require 'pathname'
require "open-uri"


def login(browser)
  browser.goto "http://www.medialoot.com/"
  browser.span(:id => "login_headline").click
  browser.text_field(:name => "username").set( ENV['MEDIALOOT_LOGIN'])
  browser.text_field(:name => "password").set(ENV['MEDIALOOT_PASSWORD'])
  browser.button(:name => "submit").click
end

def scrape(browser)
  puts "starting at #{last_scraped_page}"
  browser.goto last_scraped_page


  while (true)
    links = browser.divs(:class => "res_img").map() { |div| div.a().href }

    links.each() do |link|
      browser.a(:href => link).click
      scrape_page(browser)
      browser.back
    end

    next_button = browser.a(:text => "Next »")
    throw :finished if next_button.nil?
    next_button.click

  end


end

def scrape_page(browser)
  ## info
  list = browser.ul(:class => "info_list item_attributes")
  info = list.lis().inject({}) do |res, li|
    res[li.label.text.downcase.chop] = li.strong.text
    res
  end
  info["title"] = browser.div(:class => "item_title").h1.text
  info["url"] = browser.url
  info["designer"] = browser.div(:class => "designer_name").text.gsub(/\n.+$/, '')
  info["files_included"] = browser.div(:class => "files_included").imgs().map { |i| i.alt }
  info.delete("downloads")

  browser.url =~ /\/([^\/]+)\/$/
  name = $1

  json_path = Pathname.new(download_directory).join("#{name}.json")
  if json_path.exist?
    puts "#{$1} already downloaded"
    throw :finished
  else
    puts "downloading #{$1}"
    browser.a(:class => "btn_member").click
    info["file"] = wait_for_download_to_complete()
  end

  ## image
  image_path = Pathname.new(download_directory).join("#{name}.png")
  File.open(image_path, 'wb') do |fo|
    fo.write open(browser.div(:id => "slideshow").imgs[0].src).read
  end


  ## create json
  File.open(json_path, "w") do |f|
    f.write(JSON.pretty_generate(info))
  end

  @resource_index = @resource_index + 1

end

def wait_for_download_to_complete
  sleep(5)

  file_name = Dir.glob(File.join(download_directory, "*part"))[0].gsub(/\.part/, '') unless Dir.glob(File.join(download_directory, "*part")).size() == 0
  while (Dir.glob(File.join(download_directory, "*part")).size() > 0)
    sleep(1)
  end
  return file_name || ''

end


@resource_index = 0

def last_scraped_page
  "http://medialoot.com/browse/all/date/all/all/all/#{@resource_index}/"
end

def download_directory
  @download_directory ||= "#{Dir.pwd}/downloads"
end


catch(:finished) do
  while (true)
    begin

      profile = Selenium::WebDriver::Firefox::Profile.new
      profile['browser.download.folderList'] = 2 # custom location
      profile['browser.download.dir'] = download_directory
      profile['browser.helperApps.neverAsk.saveToDisk'] = "application/zip"
      profile['app.update.enabled'] = false

      browser = Watir::Browser.new :ff, :profile => profile
      login(browser)
      scrape(browser)

    rescue :finished
      puts "Finished"
      break

    rescue Exception => e
      puts "#{e.to_s} happened"
    ensure
      browser.close
    end
  end
end


