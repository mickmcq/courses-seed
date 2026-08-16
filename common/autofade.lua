function BulletList(node)
    local result = pandoc.Div(node.content:map(function(blocks)
        -- apparently revealjs uses inline-block for lists, so we wrap them
        -- in a div to make them block
        local div = pandoc.Div({pandoc.BulletList(blocks)})
        div.attr = pandoc.Attr("", {"fragment", "fade-in-then-semi-out"})
        return div
    end))
    return result
end
