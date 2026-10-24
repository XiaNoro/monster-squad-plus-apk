using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

public static class ProtoDump
{
    class Field { public int Num; public int Wire; public ulong V; public byte[] B; }

    static ulong Varint(byte[] d, ref int p, int end)
    {
        ulong r = 0; int s = 0;
        while (true)
        {
            if (p >= end || s > 63) throw new Exception("bad varint");
            byte b = d[p++]; r |= (ulong)(b & 0x7f) << s; s += 7;
            if ((b & 0x80) == 0) return r;
        }
    }

    // Parses fields; if maxField>0, stops (without error) at the first field outside 1..maxField or malformed data.
    static List<Field> Parse(byte[] d, int start, int end, int maxField, out int stop)
    {
        var list = new List<Field>(); int p = start; stop = start;
        while (p < end)
        {
            int save = p;
            try
            {
                ulong tag = Varint(d, ref p, end);
                int num = (int)(tag >> 3), wire = (int)(tag & 7);
                if (num < 1 || (maxField > 0 && num > maxField)) { p = save; break; }
                var f = new Field { Num = num, Wire = wire };
                if (wire == 0) f.V = Varint(d, ref p, end);
                else if (wire == 2)
                {
                    ulong len = Varint(d, ref p, end);
                    if (len > (ulong)(end - p)) throw new Exception("len");
                    f.B = new byte[len]; Array.Copy(d, p, f.B, 0, (int)len); p += (int)len;
                }
                else if (wire == 5) { p += 4; if (p > end) throw new Exception("w5"); }
                else if (wire == 1) { p += 8; if (p > end) throw new Exception("w1"); }
                else throw new Exception("wire");
                list.Add(f); stop = p;
            }
            catch { if (maxField > 0) { p = save; break; } throw; }
        }
        stop = p;
        return list;
    }

    static List<Field> Sub(byte[] b) { int s; return Parse(b, 0, b.Length, 0, out s); }
    static string Str(byte[] b) { return Encoding.UTF8.GetString(b); }

    static readonly string[] Types = { "", "double", "float", "int64", "uint64", "int32", "fixed64", "fixed32", "bool", "string", "group", "message", "bytes", "uint32", "enum", "sfixed32", "sfixed64", "sint32", "sint64" };
    static readonly string[] Labels = { "", "optional", "required", "repeated" };

    static void Enum(StringBuilder sb, byte[] b, string ind)
    {
        string name = ""; var vals = new List<string>();
        foreach (var f in Sub(b))
        {
            if (f.Num == 1) name = Str(f.B);
            else if (f.Num == 2)
            {
                string vn = ""; long vv = 0;
                foreach (var g in Sub(f.B)) { if (g.Num == 1) vn = Str(g.B); else if (g.Num == 2) vv = (int)(long)g.V; }
                vals.Add(ind + "  " + vn + " = " + vv + ";");
            }
        }
        sb.AppendLine(ind + "enum " + name + " {");
        foreach (var v in vals) sb.AppendLine(v);
        sb.AppendLine(ind + "}");
    }

    static void Msg(StringBuilder sb, byte[] b, string ind)
    {
        var fs = Sub(b); string name = "";
        foreach (var f in fs) if (f.Num == 1) name = Str(f.B);
        sb.AppendLine(ind + "message " + name + " {");
        foreach (var f in fs)
        {
            if (f.Num == 2)
            {
                string fn = "", tn = "", def = null; int num = 0, lab = 1, ty = 0;
                foreach (var g in Sub(f.B))
                {
                    switch (g.Num)
                    {
                        case 1: fn = Str(g.B); break;
                        case 3: num = (int)g.V; break;
                        case 4: lab = (int)g.V; break;
                        case 5: ty = (int)g.V; break;
                        case 6: tn = Str(g.B); break;
                        case 7: def = Str(g.B); break;
                    }
                }
                string t = (ty == 11 || ty == 14) && tn != "" ? tn : (ty < Types.Length ? Types[ty] : "?" + ty);
                string d = def != null ? " [default = " + (ty == 9 ? "\"" + def + "\"" : def) + "]" : "";
                sb.AppendLine(ind + "  " + Labels[lab] + " " + t + " " + fn + " = " + num + d + ";");
            }
            else if (f.Num == 3) Msg(sb, f.B, ind + "  ");
            else if (f.Num == 4) Enum(sb, f.B, ind + "  ");
        }
        sb.AppendLine(ind + "}");
    }

    public static string Dump(string path)
    {
        byte[] d = File.ReadAllBytes(path);
        var outSb = new StringBuilder();
        var seen = new HashSet<string>();
        for (int i = 0; i + 4 < d.Length; i++)
        {
            if (d[i] != 0x0A) continue;
            int n = d[i + 1];
            if (n < 4 || n > 100 || i + 2 + n > d.Length) continue;
            string nm = Encoding.ASCII.GetString(d, i + 2, n);
            if (!nm.EndsWith(".proto") || nm.IndexOf('\0') >= 0) continue;
            int stop;
            List<Field> top;
            try { top = Parse(d, i, d.Length, 12, out stop); } catch { continue; }
            int msgs = 0; foreach (var f in top) if (f.Num == 4 || f.Num == 5) msgs++;
            if (msgs == 0 || !seen.Add(nm)) continue;
            var sb = new StringBuilder();
            sb.AppendLine("// " + nm + "  (offset 0x" + i.ToString("X") + ", " + (stop - i) + " bytes)");
            foreach (var f in top)
            {
                if (f.Num == 2) sb.AppendLine("package " + Str(f.B) + ";");
                else if (f.Num == 3) sb.AppendLine("import \"" + Str(f.B) + "\";");
            }
            foreach (var f in top)
            {
                if (f.Num == 4) Msg(sb, f.B, "");
                else if (f.Num == 5) Enum(sb, f.B, "");
                else if (f.Num == 6)
                {
                    foreach (var g in Sub(f.B)) if (g.Num == 1) sb.AppendLine("service " + Str(g.B) + " { ... }");
                }
            }
            string safe = nm.Replace('/', '_');
            File.WriteAllText(Path.Combine(Path.GetDirectoryName(path), "..", "..", "..", "protos", safe), sb.ToString());
            outSb.AppendLine(nm + " : " + msgs + " top-level types, " + (stop - i) + " bytes");
        }
        return outSb.ToString();
    }
}
