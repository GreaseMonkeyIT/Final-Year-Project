"""Assemble the notebook: concatenate the parts and inline the generated SVGs."""
import os, re, glob

HERE = os.path.dirname(os.path.abspath(__file__))
PARTS = sorted(glob.glob(os.path.join(HERE, 'parts', '*.html')))
CHARTS = os.path.join(HERE, 'charts')
# the finished book sits one level up, beside the source folder
OUT = os.path.abspath(os.path.join(HERE, os.pardir, 'MPPT_and_Partial_Shading.html'))
if not os.path.isdir(os.path.dirname(OUT)):
    OUT = os.path.join(HERE, 'MPPT_and_Partial_Shading.html')

CAPTIONS = {
 'cell_iv': 'Figure 2.3 &#8212; The complete characteristic of one cell, drawn from the reference '
            'module divided by its 60 cells. The shaded rectangle is the power delivered at the '
            'maximum power point. The fill factor is that rectangle divided by the '
            'V<sub>oc</sub> &#215; I<sub>sc</sub> rectangle that encloses the curve.',
 'irradiance_iv': 'Figure 3.1 &#8212; Five irradiance levels. The curves are very nearly vertical '
            'scalings of one another. The plateau height follows the light exactly; the knee '
            'hardly moves.',
 'irradiance_pv': 'Figure 3.2 &#8212; The same five levels in the power plane. Each has exactly one '
            'peak. A ten-to-one fall in light moves the peak voltage left by only 2.7 V.',
 'temp_iv': 'Figure 3.3 &#8212; Four cell temperatures at full sun. Now the knee is what moves, and '
            'it moves a long way; the plateau barely changes.',
 'temp_pv': 'Figure 3.4 &#8212; Running at 65 &#176;C instead of 25 &#176;C costs 15 % of the peak '
            'power and moves V<sub>mp</sub> down by 4.8 V. A tracker must follow this drift all day.',
 'rs_effect': 'Figure 2.5 &#8212; Increasing R<sub>s</sub> shears the knee down and to the left. '
            'V<sub>oc</sub> is unchanged, because no current flows through R<sub>s</sub> at open '
            'circuit. The fill factor falls.',
 'rsh_effect': 'Figure 2.6 &#8212; Reducing R<sub>sh</sub> tilts the flat part of the curve. '
            'I<sub>sc</sub> is almost unchanged, but voltage and fill factor are both lost.',
 'loadline': 'Figure 4.1 &#8212; The operating point is where the panel curve meets the load. Only '
            'one load, R = 3.62 &#8486;, happens to sit at the maximum power point, and only at '
            'this irradiance and temperature.',
 'ratio_stability': 'Figure 5.2 &#8212; Both ratios are remarkably steady. This is why a single '
            'stored constant can put a tracker within about 1 % of the peak with one measurement.',
 'po_hill': 'Figure 6.1 &#8212; Each dot is one perturbation. The algorithm keeps its direction '
            'while the power rises and reverses when it falls, so at steady state it oscillates '
            'across the top by one step in each direction.',
 'inccond': 'Figure 6.3 &#8212; The same curve differentiated. Note how steep the right-hand side '
            'is: overshooting past V<sub>mp</sub> is much more expensive than undershooting.',
 'reverse_bias': 'Figure 8.1 &#8212; The shaded cell cannot supply the string current from light, so '
            'it is pushed to a negative voltage until avalanche breakdown lets the current through. '
            'The dissipation shown is the model value; the true ceiling is whichever is smaller, the '
            'breakdown voltage or the power the healthy cells in the same bypass group can generate.',
 'string_iv': 'Figure 9.1 &#8212; Each step down is one bypass diode starting to conduct. Compare '
            'with the smooth uniform curve behind it.',
 'string_pv': 'Figure 9.2 &#8212; Three peaks. A local tracker that starts anywhere except the '
            'middle section will stop on the wrong one and hold about three quarters of the '
            'available power.',
 'patterns': 'Figure 9.3 &#8212; The number and position of the peaks depend on the pattern, not '
            'only on how much light is lost. Every dot is a local maximum.',
 'windows': 'Figure 10.1 &#8212; The labels under each peak give its voltage as a fraction of '
            'k &#215; V<sub>oc,mod</sub>. All four fall in the published 0.70 to 0.95 band, which is '
            'what makes the window search safe.',
 'combine_series': 'Figure 7.1 &#8212; Two identical modules in series, drawn from the model. '
            'At any chosen current the combined voltage is exactly twice the single-module voltage. '
            'The current is unchanged.',
 'combine_parallel': 'Figure 7.2 &#8212; The same two modules in parallel. At any chosen voltage the '
            'combined current is exactly twice the single-module current. The voltage is unchanged.',
 'budget': 'Figure 11.1 &#8212; Indicative figures for a four-module string, using common parameter '
            'choices for each method. The ranking, not the exact numbers, is the point: cost is '
            'dominated by how many operating points must be applied and allowed to settle.',
}


def figure(name):
    path = os.path.join(CHARTS, name + '.svg')
    with open(path) as f:
        svg = f.read()
    cap = CAPTIONS.get(name, '')
    return (f'<figure>\n<div class="figwrap">\n{svg}\n</div>\n'
            f'<figcaption>{cap}</figcaption>\n</figure>')


def main():
    html = []
    for p in PARTS:
        with open(p) as f:
            html.append(f.read())
    doc = '\n'.join(html)
    doc = doc.replace('<p class="figcapx"></p>', '')
    missing = []

    def sub(mo):
        name = mo.group(1)
        if not os.path.exists(os.path.join(CHARTS, name + '.svg')):
            missing.append(name)
            return mo.group(0)
        return figure(name)

    doc = re.sub(r'<!--FIG:([a-z0-9_]+)-->', sub, doc)
    with open(OUT, 'w') as f:
        f.write(doc)
    used = set(re.findall(r'class="fig"', doc))
    print('parts     :', len(PARTS))
    print('figures   :', doc.count('<figure>'))
    print('missing   :', missing or 'none')
    print('size      : %.1f KB' % (os.path.getsize(OUT) / 1024))
    print('out       :', OUT)


if __name__ == '__main__':
    main()
