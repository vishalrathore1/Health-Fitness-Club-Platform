
document.addEventListener("DOMContentLoaded", () => {

    console.log("FitClub Website Loaded Successfully!");

    // Smooth navigation
    document.querySelectorAll('a[href^="#"]').forEach(link => {

        link.addEventListener("click", function(event) {

            const target = document.querySelector(
                this.getAttribute("href")
            );

            if (target) {
                event.preventDefault();

                target.scrollIntoView({
                    behavior: "smooth"
                });
            }

        });

    });

});
