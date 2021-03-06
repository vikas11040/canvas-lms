define [
  'i18n!gradebook2'
  'underscore'
  'Backbone'
  'vendor/slickgrid'
  'compiled/gradebook2/OutcomeGradebookGrid'
  'compiled/views/gradebook/CheckboxView'
  'compiled/views/gradebook/SectionMenuView'
  'jst/gradebook2/outcome_gradebook'
  'vendor/jquery.ba-tinypubsub'
], (I18n, _, {View}, Slick, Grid, CheckboxView, SectionMenuView, template, cellTemplate) ->

  Dictionary =
    mastery:
      color : '#8bab58'
      label : I18n.t('mastery', 'mastery')
    nearMastery:
      color : '#e0d679'
      label : I18n.t('near_mastery', 'near mastery')
    remedial:
      color : '#dd5c5c'
      label : I18n.t('remedial', 'remedial')

  class OutcomeGradebookView extends View

    tagName: 'div'

    className: 'outcome-gradebook-container'

    template: template

    @optionProperty 'gradebook'

    hasOutcomes: $.Deferred()

    # child views rendered using the {{view}} helper in the template
    checkboxes:
      mastery:        new CheckboxView(Dictionary.mastery)
      'near-mastery': new CheckboxView(Dictionary.nearMastery)
      remedial:       new CheckboxView(Dictionary.remedial)

    events:
      'click .sidebar-toggle': 'onSidebarToggle'

    constructor: (options) ->
      super
      @_validateOptions(options)

    # Public: Show/hide the sidebar.
    #
    # e - Event object.
    #
    # Returns nothing.
    onSidebarToggle: (e) ->
      e.preventDefault()
      isCollapsed = @_toggleSidebarCollapse()
      @_toggleSidebarArrow()
      @_toggleSidebarTooltips(isCollapsed)

    # Internal: Toggle collapsed class on sidebar.
    #
    # Returns true if collapsed, false if expanded.
    _toggleSidebarCollapse: ->
      @$('.outcome-gradebook-sidebar')
        .toggleClass('collapsed')
        .hasClass('collapsed')

    # Internal: Toggle the direction of the sidebar collapse arrow.
    #
    # Returns nothing.
    _toggleSidebarArrow: ->
      @$('.sidebar-toggle')
        .toggleClass('icon-arrow-right')
        .toggleClass('icon-arrow-left')

    # Internal: Toggle the direction of the sidebar collapse arrow.
    #
    # Returns nothing.
    _toggleSidebarTooltips: (shouldShow) ->
      if shouldShow
        @$('.checkbox-view').each ->
          $(this).find('.checkbox')
            .attr('data-tooltip', 'left')
            .attr('title', $(this).find('.checkbox-label').text())
      else
        @$('.checkbox').removeAttr('data-tooltip').removeAttr('title')

    # Internal: Validate options passed to constructor.
    #
    # options - The options hash passed to the constructor function.
    #
    # Returns nothing on success, raises on failure.
    _validateOptions: ({gradebook}) ->
      throw new Error('Missing required option: "gradebook"') unless gradebook

    # Internal: Listen for events on child views.
    #
    # Returns nothing.
    _attachEvents: ->
      view.on('togglestate', @_createFilter(name)) for name, view of @checkboxes
      $.subscribe('currentSection/change', Grid.Events.sectionChangeFunction(@grid))

    # Public: Create object to be passed to the view.
    #
    # Returns an object.
    toJSON: ->
      _.extend({}, @checkboxes, menu: @menu)

    # Public: Render the view once all needed data is loaded.
    #
    # Returns this.
    render: ->
      $.when(@gradebook.hasSections)
        .then(@_initMenu)
        .then(=> super)
      $.when(@hasOutcomes).then(@renderGrid)
      this

    # Internal: Render SlickGrid component.
    #
    # response - Outcomes rollup data from API.
    #
    # Returns nothing.
    renderGrid: (response) =>
      Grid.Util.saveOutcomes(response.linked.outcomes)
      Grid.Util.saveStudents(response.linked.users)
      [columns, rows] = Grid.Util.toGrid(response, column: { formatter: Grid.View.cell }, row: { section: @menu.currentSection })
      @grid = new Slick.Grid(
        '.outcome-gradebook-wrapper',
        rows,
        columns,
        Grid.options)
      @grid.onHeaderRowCellRendered.subscribe(Grid.Events.headerRowCellRendered)
      @grid.onHeaderCellRendered.subscribe(Grid.Events.headerCellRendered)
      @grid.init()
      Grid.Events.init(@grid)
      @_attachEvents()

    # Public: Pass outcomes from outcome rollup API to the view.
    #
    # outcomeResponse - The JSON response from Canvas.
    #
    # Returns nothing.
    loadOutcomes: (outcomeResponse) ->
      @hasOutcomes.resolve(outcomeResponse)

    # Internal: Initialize the child SectionMenuView. This happens here because
    #   the menu needs to wait for relevant course sections to load.
    #
    # Returns nothing.
    _initMenu: =>
      @menu = new SectionMenuView(
        sections: @gradebook.sectionList()
        currentSection: @gradebook.sectionToShow
        className: 'outcome-gradebook-section-select'
      )

    # Internal: Create an event listener function used to filter SlickGrid results.
    #
    # name - The class name to toggle on/off (e.g. 'mastery', 'remedial').
    #
    # Returns a function.
    _createFilter: (name) ->
      filterFunction = (isChecked) =>
        Grid.filter = if isChecked
          _.uniq(Grid.filter.concat([name]))
        else
          _.reject(Grid.filter, (o) -> o == name)
        @grid.invalidate()
