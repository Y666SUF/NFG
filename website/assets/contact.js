(function () {
  var form = document.getElementById("contactForm");
  var status = document.getElementById("contactStatus");
  if (!form || !status) return;

  function setStatus(message) {
    status.textContent = message;
  }

  form.addEventListener("submit", async function (event) {
    event.preventDefault();
    var name = String(document.getElementById("contactName").value || "").trim();
    var email = String(document.getElementById("contactEmail").value || "").trim();
    var subject = String(document.getElementById("contactSubject").value || "").trim();
    var message = String(document.getElementById("contactMessage").value || "").trim();

    if (!name || !email || !subject || !message) {
      setStatus("Please complete all fields.");
      return;
    }

    setStatus("Sending...");

    try {
      var response = await fetch("/api/contact", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: name, email: email, subject: subject, message: message }),
      });
      var body = await response.json().catch(function () {
        return {};
      });
      if (!response.ok || !body.ok) {
        setStatus(body.message || "Could not send message right now. Please try again later.");
        return;
      }
      form.reset();
      setStatus("Message sent successfully.");
    } catch (_err) {
      setStatus("Could not send message right now. Please try again later.");
    }
  });
})();
