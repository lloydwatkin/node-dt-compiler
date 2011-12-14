{ isArray } = Array

# /** PrivateConstants: DOM Element Type Constants
#  *  DOM element types.
#  *
#  *  ElementType.NORMAL - Normal element.
#  *  ElementType.TEXT - Text data element.
#  *  ElementType.FRAGMENT - XHTML fragment element.
#  */
DOMElementType =
    NORMAL:   1
    TEXT:     3
    CDATA:    4
    FRAGMENT: 11

##
# copy many objects into one
deep_merge = (objs...) ->
    objs = objs[0] if isArray(objs[0])
    res = {}
    for obj in objs
        for k, v of obj
            if typeof(v) is 'object' and not isArray(v)
                res[k] = deep_merge(res[k] or {}, v)
            else
                res[k] = v
    res

##
# copy only structure and reuse objects
# except for the dom element objects (because of the children)
copy_structure = (tree) ->
    res = []
    for el in tree ? []
        if typeof el is 'string' or typeof el is 'number'
            res.push el
            continue
        res.push
            name:     el.name
            attrs:    el.attrs
            children: copy_structure(el.children)
    return res

##
# tests a tag against the dom information from jsonify
match = (tag, el) ->
    return yes unless el? # nothing to test against
    return no if tag.name isnt el.name
    for key, value of tag.attrs
        return no if el.attrs[key] isnt value
    return yes

##
# create a new tag (and children) from data structure
new_tag = (parent, el, callback) ->
    attrs = deep_merge el.attrs # copy data
    parent.tag el.name, attrs, ->
        for child in el.children.slice() ? []
            if typeof child is 'string' or typeof child is 'number'
                @text "#{child}", append:on
            else
                new_tag this, child, ->
                    callback?()
                    callback = null
        @end()
        # call back some delayed work
        callback?()

##
# apply possible additions from the data structure on the tag
mask = (tag, el) ->
    return unless el?
    # no need to set tag.name because its the most important trigger for a match
    tag.attr el.attrs # object
    tag._elems = el.children

##
# this hooks on new instanziated templates and tries to
# complete the structure with the given html design
hook = (tpl) ->
    tpl.xml.use (parent, tag, next) ->
        elems = parent._elems

        # when this is a tag created from data structure
        return next(tag) unless elems?

        repeat = ->
            el = elems[0]

            if typeof el is 'string' or typeof el is 'number'
                console.log "text".blue, el
                elems.shift() # rm text
                parent.text? el, append:on
                do repeat

            else if match tag, el
                elems.shift() # rm el
                mask tag, el # apply
                next(tag)

            else # create new tag
                # create and insert the new tag from el and delay work
                new_tag parent, el, repeat
        do repeat

##
# this add the data structure to the new instanziated template and hooks it
module.exports = link = (rawtemplate, tree) ->
    return (args...) ->
        tpl = rawtemplate args...
        # local copy of the data structure
        elems = copy_structure tree
        # nest the data tree in the root
        tpl.xml._elems = elems
        # we need to get between the events from the builder and
        # the output to change to events bahavior (inserting events before others)
        hook tpl
        # done
        return tpl
