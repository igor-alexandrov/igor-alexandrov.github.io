---
title: Lazy-load offscreen iframes!
layout: post
tags:
  - HTML
  - TIL
featured: false
hidden: false
---

A week ago I finished update of this website and it was my first front-end related task in a while. I've learned a lot of new things that I want to share with you. The may sound obvious for some of you, but I still think they deserve to be mentioned. One of them is lazy-loading offscreen iframes.

<!--more-->

For me performance of web apps really matters. I already showed [tools and techniques to improve Rails application performance](https://igor.works/blog/18-tools-and-techniques-to-improve-rails-application-performance). But a lot of optimizations can be done on a front-end too. Minimizing the number of requests, reducing the size of the files, and optimizing the loading time are crucial.

The implementation of lazy-loading for `<iframe>` elements involves delaying the loading of iframes that are not currently visible on the screen until the user scrolls in their vicinity. This strategy conserves data, enhances the loading speed of other page components, and diminishes memory usage.

I prepared two demo pages to show you how it works. They both load the same YouTube video, but [the first one](/demos/iframe-loading-lazy) uses the `<iframe loading="lazy">` attribute and [the second one](/demos/iframe-loading-eager) doesn't.

I faced the problem with iframe embeds when was working on the (public speeches page)[/public-speeches]. The initial result that I got was not satisfying. The Lighthouse audit showed that the page was not optimized.

{% include image-caption.html imageurl="/assets/images/posts/2024-05-09/loading-eager.png" title="Lighthouse results with eager loading" caption="Lighthouse results with eager loading" %}

With the lazy loading attribute, the page performance improved significantly. The Lighthouse audit showed that the page was optimized.

{% include image-caption.html imageurl="/assets/images/posts/2024-05-09/loading-lazy.png" title="Lighthouse results with lazy loading" caption="Lighthouse results with lazy loading" %}

The best part is that it's super easy to implement. Just add the `loading="lazy"` attribute to the `<iframe>` tag. [All major browsers](https://caniuse.com/loading-lazy-attr) support this attribute, so you don't need to worry about compatibility. Important to mention that the `loading="lazy"` attribute support for iframes added in Firefox only in version 121, that [has been released](https://www.mozilla.org/en-US/firefox/121.0/releasenotes/) in December 2023.

``` html
  <iframe
    loading="lazy"
    src="https://www.youtube-nocookie.com/embed/2QrZDlEfnFw"
    title="Maybe – open-source personal finance app"
  ></iframe>
```

## Why you should use iframe lazy loading?

The first and the most important reason is performance. Lazy loading of iframes can significantly improve the loading speed of your website. It's especially important for pages with a lot of iframes. The second reason is that it can save your users' data. Iframes are usually used to embed videos, audious, slides maps, or other external content. Lazy loading can help to reduce the amount of data that is loaded when the page is opened.

{% include image-caption.html imageurl="/assets/images/posts/2024-05-09/page-size.png" title="Page size with/without lazy loading" caption="Page size with/without lazy loading" width="600px" %}

Iframe lazy loading can improve you [Largest Contentful Paint (LCP)](https://web.dev/articles/lcp) metric as well as [First Input Delay (FID)](https://web.dev/articles/fid) and [First Contentful Paint (FCP)](https://web.dev/articles/fcp).

## Backward compatibility

The most wonderful thing about the `loading="lazy"` attribute is that it's backward compatible. If the browser doesn't support it, it will just ignore it. So you can safely add it to your iframes without worrying about breaking the page for users with older browsers.

This means that you can start using it right now without any risk. Just add the `loading="lazy"` attribute to your iframes and enjoy the performance improvements.