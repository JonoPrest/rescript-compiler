export const sql = (strings, ...values) => {
    let result = "";
    for (let i = 0; i < values.length; i++) {
        result += strings[i] + "'" + values[i] + "'";
    }
    result += strings[values.length];
    return result;
};

export const length = (strings, ...values) =>
    strings.reduce((acc, curr) => acc + curr.length, 0) +
        values.reduce((acc, curr) => acc + curr, 0);

// Like `sql`, but only succeeds when invoked as a real tagged template literal.
// Tagged-template invocations attach `.raw` to the strings array; a plain
// function call with two arrays does not. Used to detect regressions where the
// compiler emits a function call instead of a tagged template.
export const taggedTemplateLiteralAssert = (strings, ...values) => {
    if (!strings.raw) {
        throw new Error("taggedTemplateLiteralAssert was not invoked as a tagged template literal");
    }
    let result = "";
    for (let i = 0; i < values.length; i++) {
        result += strings[i] + "'" + values[i] + "'";
    }
    result += strings[values.length];
    return result;
};
