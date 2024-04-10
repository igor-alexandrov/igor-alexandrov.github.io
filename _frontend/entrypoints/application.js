// To see this message, follow the instructions for your Ruby framework.
//
// When using a plain API, perhaps it's better to generate an HTML entrypoint
// and link to the scripts and stylesheets, and let Vite transform it.
//
// Example: Import a stylesheet in <sourceCodeDir>/index.css
// import '~/index.css'

import "~/prism";

import { Application } from "@hotwired/stimulus";
import ScrollTo from "stimulus-scroll-to";
import Reveal from "stimulus-reveal-controller";
import ScrollProgress from "stimulus-scroll-progress";
import TextareaAutogrow from 'stimulus-textarea-autogrow'

import { createIcons, Menu, Twitter, Github, Youtube, Linkedin, ChevronLeft, ChevronRight } from 'lucide';

const application = Application.start();

application.register("scroll-to", ScrollTo);
application.register("reveal", Reveal);
application.register("scroll-progress", ScrollProgress);
application.register('textarea-autogrow', TextareaAutogrow);

createIcons({
  icons: {
    Menu,
    Twitter,
    Github,
    Youtube,
    Linkedin,
    ChevronLeft,
    ChevronRight
  }
});
