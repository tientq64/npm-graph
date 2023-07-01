do ->
	nodes = []
	links = []
	pkgs = []
	width = innerWidth
	height = innerHeight
	exclPkgsRegex = null

	forceLink = d3
		.forceLink links
		.distance (d) => 50 + d.source.r + d.target.r
		.id (d) => d.name
	forceManyBody = d3
		.forceManyBody()
		.strength -5
	forceCenter = d3
		.forceCenter 0, 0

	simul = d3
		.forceSimulation nodes
		.force "link", forceLink
		.force "charge", forceManyBody
		.force "center", forceCenter

	drag = d3
		.drag()
		.on "start", (d) =>
			simul.alphaTarget(1).restart() unless d3.event.active
			d.fx = d.x
			d.fy = d.y
			document.body.classList.add "grabbing"
			return
		.on "drag", (d) =>
			d.fx = d3.event.x
			d.fy = d3.event.y
			return
		.on "end", (d) =>
			simul.alphaTarget 0 unless d3.event.active
			d.fx = d.fy = null
			document.body.classList.remove "grabbing"
			return
	zoom = d3
		.zoom()
		.extent [[0, 0], [width, height]]
		.scaleExtent [.2, 4]
		.translateExtent [[-width, -height], [width, height]]
		.on "zoom", (d) =>
			mainEl.attr "transform", d3.event.transform
			return

	svg = d3
		.select "svg"
		.attr "width", width
		.attr "height", height
		.attr "viewBox", [0, 0, width, height]
		.call zoom
	mainEl = svg
		.append "g"
	linkEl = mainEl
		.append "g"
		.classed "links", yes
	linkEls = null
	nodeEl = mainEl
		.append "g"
		.classed "nodes", yes
	nodeEls = null
	textEl = mainEl
		.append "g"
		.classed "texts", yes
	textEls = null

	zoom.translateTo svg, 0, 0

	simul.on "tick", =>
		linkEls
			.attr "x1", (d) => d.source.x
			.attr "y1", (d) => d.source.y
			.attr "x2", (d) => d.target.x
			.attr "y2", (d) => d.target.y
		nodeEls.attr "transform", (d) => "translate(#{d.x}, #{d.y})"
		textEls.attr "transform", (d) => "translate(#{d.x}, #{d.y})"
		return

	# exclPkgsRegex = ///
	# 	@|babel|types|jest|typescript|eslint|coveralls|cheerio|esprima|standard|d|
	# 	codecov\.io|escomplex-js|mocha|glob|tap|tsd|ava|xo|chalk|octokit|browserify|
	# 	nyc|chai|benchmark
	# ///

	loadPkg = (name, append) ->
		unless append
			nodes = []
			links = []
			pkgs = name
			pkgs = [pkgs] unless Array.isArray pkgs
			simul.stop()
		if Array.isArray name
			for v from name
				loadPkg v, yes
		else
			await loadDepend name
		return

	loadDepend = (name, parent, type, lv = 0) ->
		node = nodes.find (v) => v.name is name
		if name in pkgs and parent
			return
		if node
		else
			nodes.unshift
				name: name
				type: type
				lv: lv
				r: 1
		if parent
			links.push source: parent, target: name
			parentNode = nodes.find (v) => v.name is parent
			parentNode.r++
		linkEls = linkEl
			.selectAll "line"
			.data links
			.join "line"
		nodeEls = nodeEl
			.selectAll "circle"
			.data nodes
			.join "circle"
			.attr "r", (d) => d.r
			.attr "fill", (d) =>
				switch d.type
					# when "depend" then "#d9822b"
					when "depend" then "#d99e0b"
					when "devDepend" then "#137cbd"
					else "#db3737"
			.call drag
		textEls = textEl
			.selectAll "text"
			.data nodes
			.join "text"
			.attr "x", 4
			.text (d) => d.name
			.call drag
		simul.nodes nodes
		forceLink.links links
		simul.alphaTarget(1).restart()
		unless node
			try
				pkg = await d3.json "https://unpkg.com/#{name}/package.json"
				{dependencies, devDependencies} = pkg
				if dependencies
					for depend of dependencies
						unless exclPkgsRegex?.test depend
							await loadDepend depend, name, "depend", lv + 1
				unless parent
					if devDependencies
						for depend of devDependencies
							unless exclPkgsRegex?.test depend
								await loadDepend depend, name, "devDepend", lv + 1
		return

	await loadPkg [
		"has-flag"
	]
	return
