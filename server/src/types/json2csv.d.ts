declare module 'json2csv' {
  export interface ParserOptions<T = any> {
    fields?: Array<string | { label: string; value: string }>;
    defaultValue?: string;
    delimiter?: string;
    eol?: string;
    header?: boolean;
  }
  export class Parser<T = any> {
    constructor(opts?: ParserOptions<T>);
    parse(data: T[] | T): string;
  }
}
