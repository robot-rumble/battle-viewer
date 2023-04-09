type StringObject = {
  [key: string]: any
}

function toSnakeCase(str: string): string {
  return str.replace(/([A-Z])/g, (match) => `_${match.toLowerCase()}`)
}

export function convertObjectKeysToSnakeCase(obj: StringObject): StringObject {
  const result: StringObject = {}

  for (const key in obj) {
    const value = obj[key]
    const snakeCaseKey = toSnakeCase(key)

    if (typeof value === 'object' && value !== null) {
      if (Array.isArray(value)) {
        result[snakeCaseKey] = value.map((item) =>
          typeof item === 'object' && item !== null
            ? convertObjectKeysToSnakeCase(item)
            : item,
        )
      } else {
        result[snakeCaseKey] = convertObjectKeysToSnakeCase(value)
      }
    } else {
      result[snakeCaseKey] = value
    }
  }

  return result
}
