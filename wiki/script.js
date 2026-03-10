// Nav scroll effect
const nav = document.querySelector('.nav');
window.addEventListener('scroll', () => {
  nav.classList.toggle('scrolled', window.scrollY > 20);
});

// Mobile hamburger
const hamburger = document.querySelector('.nav-hamburger');
const navLinks = document.querySelector('.nav-links');
const MENU_ICON = 'M3 12h18M3 6h18M3 18h18';
const CLOSE_ICON = 'M18 6L6 18M6 6l12 12';

if (hamburger) {
  hamburger.addEventListener('click', () => {
    navLinks.classList.toggle('open');
    const path = hamburger.querySelector('path');
    const isOpen = navLinks.classList.contains('open');
    path.setAttribute('d', isOpen ? CLOSE_ICON : MENU_ICON);
  });
}

// Active nav link tracking
const sections = document.querySelectorAll('.section[id]');
const navAnchors = document.querySelectorAll('.nav-links a[href^="#"]');

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        navAnchors.forEach((a) => a.classList.remove('active'));
        const active = document.querySelector(`.nav-links a[href="#${entry.target.id}"]`);
        if (active) active.classList.add('active');
      }
    });
  },
  { rootMargin: '-30% 0px -60% 0px' }
);

sections.forEach((s) => observer.observe(s));

// Close mobile nav on link click
navAnchors.forEach((a) => {
  a.addEventListener('click', () => {
    navLinks.classList.remove('open');
  });
});

// Copy button
document.querySelectorAll('.code-copy').forEach((btn) => {
  btn.addEventListener('click', () => {
    const code = btn.closest('.code-section').querySelector('pre');
    const text = code.textContent;
    navigator.clipboard.writeText(text).then(() => {
      const orig = btn.textContent;
      btn.textContent = 'Copied!';
      btn.style.color = 'var(--accent-3)';
      btn.style.borderColor = 'var(--accent-3)';
      setTimeout(() => {
        btn.textContent = orig;
        btn.style.color = '';
        btn.style.borderColor = '';
      }, 2000);
    });
  });
});
