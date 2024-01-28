---
layout: page
title: Speaking Opportunities
---

As a Ruby programmer, co-founder, and CTO of a consulting company, my public talks and podcasts delve into a variety of topics spanning technology, programming, leadership, and entrepreneurship.

I'm always looking for new opportunities to share my experiences and knowledge with others. If you're interested in having me speak at your event, podcast or anywhere else please [contact me](contact-me).

{% for speaking-opportunity in site.data.speaking-opportunities %}
{% include speaking-opportunity.html %}
{% endfor %}
