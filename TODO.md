# Ideas / To be done / ToDo

## Split everything

Organize snippets by category and create snippets for each technical
usecase. Use `%include` to put them together instead of repeating yourself

```
.
├── keyboard
│   ├── de-de.ks
│   └── de-us.ks
├── lang
├── network
├── notes-and-ideas
├── partitioning
│   ├── auto-gpt-crypt.ks
│   ├── auto-gpt.ks
│   ├── auto-mbr-crypt.ks
│   └── auto-mbr.ks
├── services
├── timezone
├── user
...
```

http://www2.math.uu.se/~chris/kickstart/ (Mirror: http://archive.is/Nq0nM)
provides interesting thoughts on this.


## Bugfix: Sysliinux/dracut/Anaconda: Media validation rd.live.check not working

Not directly a kickstart issue but related. When setting the syslinux labels,
`rd.live.check` should start media validation. However, tests are not starting.
One has to debug and fix this.

See [RHEL 7 Anaconda Customization Guide, "3. Customizing the Boot
Menu"](https://red.ht/2u9wXBU) and `man dracut.cmdline` for more details and
documentation.



## Research

### Kickstart via webserver ?

  * How to generate and serve kickstart file dynamically and use it with `inst.ks=http://`
  * HTTPS/TLS possible?
  * How does this work in terms of network config from syslinux boot menu?
    Cf. https://www.redhat.com/archives/kickstart-list/2007-July/msg00035.html
  * Existing projects or create one in golang, basic HTTP server and templating?
