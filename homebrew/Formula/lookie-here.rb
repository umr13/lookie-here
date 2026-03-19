class LookieHere < Formula
  desc "Auto-focus windows on the monitor you're looking at"
  # TODO: Replace GITHUB_USERNAME with your GitHub username
  homepage "https://github.com/GITHUB_USERNAME/lookie-here"
  url "https://github.com/GITHUB_USERNAME/lookie-here.git", tag: "v0.1.0"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox", "--product", "lookie"
    bin.install ".build/release/lookie"
  end

  test do
    assert_match "Usage: lookie", shell_output("#{bin}/lookie help")
  end
end
