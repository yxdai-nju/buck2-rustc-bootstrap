TargetTriple = provider(fields = {
    "value": str,
})

def _target_triple_impl(ctx: AnalysisContext) -> list[Provider]:
    return [
        DefaultInfo(),
        TargetTriple(value = ctx.attrs.value),
        TemplatePlaceholderInfo(
            unkeyed_variables = {
                "target_triple": ctx.attrs.value,
            },
        ),
    ]

target_triple = rule(
    impl = _target_triple_impl,
    attrs = {"value": attrs.string()},
    supports_incoming_transition = True,
)
