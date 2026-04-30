from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    # Connect to the browser window you opened in Step 2
    browser = p.chromium.connect_over_cdp("http://localhost:9222")
    
    # Select the already open page
    context = browser.contexts[0]
    page = context.pages[0]

    # Test it
    page.goto("https://www.google.com")
    print("Successfully connected to your logged-in session!")
    
    # Now you can proceed with your downloads or RAG tasks