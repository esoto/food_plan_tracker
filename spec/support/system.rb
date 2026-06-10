require "capybara/rspec"
require "database_cleaner/active_record"

RSpec.configure do |config|
  # Use Selenium with headless Chrome for system specs
  # Mobile-first layout: 390x844 viewport shows bottom nav only on narrow screens
  Capybara.register_driver :selenium do |app|
    Selenium::WebDriver.logger.ignore(:browser_version)
    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      capabilities: [
        Selenium::WebDriver::Chrome::Options.new(
          args: [
            "--headless=new",
            "--disable-dev-shm-usage",
            "--no-sandbox",
            "--disable-gpu"
          ],
          window_size: [390, 844]
        )
      ]
    )
  end


  # DatabaseCleaner configuration: truncation for system specs ONLY
  # Transactional fixtures remain on for all other spec types
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each, type: :system) do
    Capybara.current_driver = :selenium
    # Browser requests hit the app server on a separate DB connection; data
    # must be committed, so truncation replaces transactional rollback here.
    self.use_transactional_tests = false
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  config.append_after(:each, type: :system) do
    Capybara.use_default_driver
    DatabaseCleaner.clean
  end

  # Screenshot on failure for system specs
  config.after(:each, type: :system) do |example|
    if example.exception.present?
      screenshots_dir = Rails.root.join("tmp/screenshots")
      FileUtils.mkdir_p(screenshots_dir)
      screenshot_path = screenshots_dir.join("#{example.description.parameterize}.png")
      page.save_screenshot(screenshot_path)
    end
  end
end
