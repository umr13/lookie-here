class LookieHere < Formula
  desc "Auto-focus windows on the monitor you're looking at"
  homepage "https://github.com/umr13/lookie-here"
  url "https://github.com/umr13/lookie-here.git", tag: "v0.1.0"
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
