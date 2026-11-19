NATURES = ['Hardy', 'Lonely', 'Brave', 'Adamant', 'Naughty', 'Bold', 'Docile', 'Relaxed', 'Impish', 'Lax',
           'Timid', 'Hasty', 'Serious', 'Jolly', 'Naive', 'Modest', 'Mild', 'Quiet', 'Bashful', 'Rash',
           'Calm', 'Gentle', 'Sassy', 'Careful', 'Quirky']


def slug(const, prefix):
    return const[len(prefix):].lower().replace('_', '-')
