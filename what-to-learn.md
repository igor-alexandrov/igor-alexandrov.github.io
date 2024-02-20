---
layout: page
title: What to Learn?
published: false
---

I learn something new every day. On this page, I will keep a list of courses, blogs, books, and articles I want to read, have read, want to take, or have taken.

## Courses

<ul>
  {% for course in site.data.courses %}
    <li>
      <p>
        <a
          target="_blank"
          href="{{ course.url }}"
          rel="noopener"
        >{{ course.title }}</a>
      </p>
      <p>
        {{ course.description }}
      </p>
    </li>
  {% endfor %}
</ul>
